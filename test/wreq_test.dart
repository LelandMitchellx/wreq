import 'package:test/test.dart';
import 'package:wreq/wreq.dart';

void main() {
  group('Ticket 01: 基础库版本查询与原生资产自动构建验证', () {
    test('getWreqVersion 返回符合规范的语义化版本字符串 (SemVer)', () {
      final version = getWreqVersion();
      expect(version, isNotEmpty);
      expect(version, matches(RegExp(r'^wreq-\d+\.\d+\.\d+.*$')));
    });

    test('多次连续调用 getWreqVersion 保持幂等且内存安全无崩溃', () {
      final initial = getWreqVersion();
      for (var i = 0; i < 50; i++) {
        final current = getWreqVersion();
        expect(current, equals(initial));
      }
    });
  });

  group('Ticket 02: 核心 GET 请求与异步 Tokio 后台网络执行', () {
    test('wreqGet 异步执行并返回包含状态码与正文的 WreqResponse', () async {
      final response = await wreqGet('https://pingly.us.kg/api/all');
      expect(response, isA<WreqResponse>());
      expect(response.statusCode, equals(200));
      expect(response.body, isNotEmpty);
      expect(response.body, contains('pingly'));
    });
  });

  group('Ticket 03: 健壮的 C-ABI 错误拦截与结构化 Dart 异常映射', () {
    test('传入畸形 URL 时抛出强类型的 WreqException', () async {
      expect(
        () => wreqGet('invalid://host'),
        throwsA(
          isA<WreqException>().having((e) => e.message, 'message', isNotEmpty),
        ),
      );
    });

    test('异常可被常规 try-catch 结构捕获并包含状态码与错误信息', () async {
      try {
        await wreqGet('invalid-protocol://error');
        fail('应当抛出 WreqException 但未抛出');
      } on WreqException catch (e) {
        expect(e.message, isNotEmpty);
        expect(e.statusCode, equals(-1));
      }
    });

    test('目标主机不可达或无效域名时安全拦截并抛出 WreqException', () async {
      expect(
        () => wreqGet('http://nonexistent-subdomain-123456789.com'),
        throwsA(
          isA<WreqException>().having((e) => e.message, 'message', isNotEmpty),
        ),
      );
    });
  });

  group('Ticket 04: 请求参数定制与自定义请求头扩展', () {
    test('设置极短超时时间（如 1ms）时，触发并捕获超时异常', () async {
      expect(
        () => wreqGet(
          'https://httpbin.org/delay/2',
          timeout: const Duration(milliseconds: 1),
        ),
        throwsA(
          isA<WreqException>().having(
            (e) => e.message.toLowerCase(),
            'message',
            anyOf(contains('timeout'), contains('timed out')),
          ),
        ),
      );
    });

    test('支持传递自定义请求头并成功在响应中回显验证', () async {
      final response = await wreqGet(
        'https://httpbin.org/headers',
        headers: {'X-Custom-Client': 'Wreq-Dart-Client'},
      );
      expect(response.statusCode, equals(200));
      expect(response.body, contains('Wreq-Dart-Client'));
    });

    test('支持指定最新版本的 EmulationProfile 模拟浏览器环境', () async {
      final chromeRes = await wreqGet(
        'https://pingly.us.kg/api/all',
        emulation: EmulationProfile.chrome149,
      );
      expect(chromeRes.statusCode, equals(200));
      expect(chromeRes.body, isNotEmpty);

      final safariRes = await wreqGet(
        'https://pingly.us.kg/api/all',
        emulation: EmulationProfile.safariIos26_2,
      );
      expect(safariRes.statusCode, equals(200));
    });
  });

  group('Ticket 05: 响应生命周期与确定性内存自动释放', () {
    test('WreqResponse 支持显式 dispose() 并准确标记释放状态', () async {
      final response = await wreqGet('https://pingly.us.kg/api/all');
      expect(response.isDisposed, isFalse);
      expect(response.body, isNotEmpty);

      // 显式释放底层内存资源
      response.dispose();
      expect(response.isDisposed, isTrue);

      // 重复调用 dispose 保证幂等安全
      expect(() => response.dispose(), returnsNormally);

      // 释放后再尝试访问 body 抛出 StateError 规避 UAF / 脏内存读取
      expect(() => response.body, throwsStateError);
    });

    test('并发与高频请求场景下内存生命周期稳定无段错误崩溃', () async {
      // 连续发起多次请求并交错使用显式释放与依赖垃圾回收
      final futures = List.generate(10, (index) async {
        final res = await wreqGet('https://pingly.us.kg/api/all');
        expect(res.statusCode, equals(200));
        if (index.isEven) {
          res.dispose();
        }
      });
      await Future.wait(futures);
    });
  });
}
