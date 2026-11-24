import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    final extraEnv = <String, String>{'CMAKE_GENERATOR': 'Ninja'};

    final rootDir = p.fromUri(input.packageRoot);
    final isTargetingWindows = input.config.code.targetOS == OS.windows;
    final isTargetingAndroid = input.config.code.targetOS == OS.android;

    // Try reusing pre-built BoringSSL artifacts (e.g. from previous builds or root build)
    // to avoid duplicate CMake executions and MAX_PATH issues on Windows.
    final targetArtifactName = isTargetingWindows
        ? 'crypto.lib'
        : 'libcrypto.a';
    final searchRoots = [
      p.join(rootDir, '.dart_tool', 'hooks_runner', 'shared', 'wreq', 'build'),
      p.join(
        rootDir,
        '..',
        '.dart_tool',
        'hooks_runner',
        'shared',
        'wreq',
        'build',
      ),
    ];
    for (final searchRoot in searchRoots) {
      final dir = Directory(searchRoot);
      if (dir.existsSync()) {
        try {
          for (final entity in dir.listSync(
            recursive: true,
            followLinks: false,
          )) {
            if (entity is File &&
                p.basename(entity.path).toLowerCase() == targetArtifactName) {
              final parentPath = entity.path.replaceAll(r'\', '/');
              if (isTargetingAndroid) {
                final archStr = input.config.code.targetArchitecture.name;
                if (!parentPath.contains(archStr) &&
                    !parentPath.contains('aarch64')) {
                  continue;
                }
              }
              final buildDir = entity.parent.path;
              final includeDir = p.join(
                entity.parent.parent.path,
                'boringssl',
                'include',
              );
              if (Directory(includeDir).existsSync()) {
                extraEnv['BORING_BSSL_PATH'] = buildDir;
                extraEnv['BORING_BSSL_INCLUDE_PATH'] = includeDir;
                extraEnv['BORING_BSSL_ASSUME_PATCHED'] = '1';
                break;
              }
            }
          }
        } catch (_) {}
      }
      if (extraEnv.containsKey('BORING_BSSL_PATH')) break;
    }

    String? ndkDir;
    if (isTargetingAndroid) {
      ndkDir =
          Platform.environment['ANDROID_NDK_HOME'] ??
          Platform.environment['NDK_HOME'] ??
          Platform.environment['ANDROID_NDK_ROOT'];

      String? clangPath;
      if (input.config.code.cCompiler?.compiler != null) {
        clangPath = p.fromUri(input.config.code.cCompiler!.compiler);
        var current = Directory(p.dirname(clangPath));
        while (current.parent.path != current.path) {
          if (File(p.join(current.path, 'source.properties')).existsSync()) {
            ndkDir ??= current.path;
            break;
          }
          current = current.parent;
        }
      }

      if (ndkDir == null) {
        final androidHome =
            Platform.environment['ANDROID_HOME'] ??
            Platform.environment['ANDROID_SDK_ROOT'];
        if (androidHome != null) {
          final ndkParent = Directory(p.join(androidHome, 'ndk'));
          if (ndkParent.existsSync()) {
            final versions = ndkParent
                .listSync()
                .whereType<Directory>()
                .toList();
            if (versions.isNotEmpty) {
              versions.sort((a, b) => b.path.compareTo(a.path));
              ndkDir = versions.first.path;
            }
          }
        }
      }

      if (ndkDir != null) {
        extraEnv['ANDROID_NDK_HOME'] = ndkDir;

        final apiLevel = input.config.code.android.targetNdkApi;
        final abi = switch (input.config.code.targetArchitecture) {
          Architecture.arm64 => 'arm64-v8a',
          Architecture.arm => 'armeabi-v7a',
          Architecture.x64 => 'x86_64',
          Architecture.ia32 => 'x86',
          Architecture.riscv64 => 'riscv64',
          _ => 'arm64-v8a',
        };
        final targetTriple = switch (input.config.code.targetArchitecture) {
          Architecture.arm64 => 'aarch64-linux-android',
          Architecture.arm => 'armv7-linux-androideabi',
          Architecture.x64 => 'x86_64-linux-android',
          Architecture.ia32 => 'i686-linux-android',
          Architecture.riscv64 => 'riscv64-linux-android',
          _ => 'aarch64-linux-android',
        };

        // Determine toolchain sysroot for bindgen
        var sysrootFlags = '';
        if (clangPath != null) {
          final ndkToolchainRoot = p.dirname(p.dirname(clangPath));
          final sysroot = p
              .join(ndkToolchainRoot, 'sysroot')
              .replaceAll(r'\', '/');
          final extraInclude = '$sysroot/usr/include/$targetTriple';
          sysrootFlags = '--sysroot=$sysroot -I$extraInclude ';
        }

        // Fix NDK unversioned target triples error in bindgen (sys/cdefs.h requires __ANDROID_API__)
        final bindgenClangArgs =
            '$sysrootFlags--target=$targetTriple$apiLevel -D__ANDROID_API__=$apiLevel';
        extraEnv['BINDGEN_EXTRA_CLANG_ARGS_${targetTriple.replaceAll('-', '_')}'] =
            bindgenClangArgs;
        extraEnv['BINDGEN_EXTRA_CLANG_ARGS'] = bindgenClangArgs;

        // Generate an explicit Android CMake toolchain wrapper to avoid CMAKE_SYSTEM_NAME reset
        // on subsequent CMake configure passes in btls-sys
        final toolchainWrapper = File(
          p.join(rootDir, '.dart_tool', 'android_toolchain_$abi.cmake'),
        );
        await toolchainWrapper.parent.create(recursive: true);
        final ndkToolchainPath = p
            .join(ndkDir, 'build', 'cmake', 'android.toolchain.cmake')
            .replaceAll(r'\', '/');
        await toolchainWrapper.writeAsString('''
set(CMAKE_SYSTEM_NAME Android)
set(ANDROID_ABI $abi)
set(ANDROID_PLATFORM $apiLevel)
include("$ndkToolchainPath")
''');
        extraEnv['CMAKE_TOOLCHAIN_FILE'] = toolchainWrapper.path;
      }
    }

    final rustBuilder = RustBuilder(
      assetName: 'src/bindings.dart',
      buildMode: BuildMode.release,
      extraCargoEnvironmentVariables: extraEnv,
    );
    await rustBuilder.run(
      input: input,
      output: output,
      logger: Logger('')
        ..level = Level.ALL
        ..onRecord.listen((record) {
          // ignore: avoid_print
          print(record.message);
        }),
    );

    // Bundle libc++_shared.so on Android since BoringSSL C++ requires libc++ runtime
    if (isTargetingAndroid && ndkDir != null) {
      final ndkArchDir = switch (input.config.code.targetArchitecture) {
        Architecture.arm64 => 'aarch64-linux-android',
        Architecture.arm => 'arm-linux-androideabi',
        Architecture.x64 => 'x86_64-linux-android',
        Architecture.ia32 => 'i686-linux-android',
        Architecture.riscv64 => 'riscv64-linux-android',
        _ => 'aarch64-linux-android',
      };
      final ndkPrebuilt = p.join(ndkDir, 'toolchains', 'llvm', 'prebuilt');
      if (Directory(ndkPrebuilt).existsSync()) {
        for (final hostDir in Directory(
          ndkPrebuilt,
        ).listSync().whereType<Directory>()) {
          final libcxxFile = File(
            p.join(
              hostDir.path,
              'sysroot',
              'usr',
              'lib',
              ndkArchDir,
              'libc++_shared.so',
            ),
          );
          if (libcxxFile.existsSync()) {
            output.assets.code.add(
              CodeAsset(
                package: input.packageName,
                name: 'libc++_shared.so',
                linkMode: DynamicLoadingBundled(),
                file: libcxxFile.uri,
              ),
            );
            break;
          }
        }
      }
    }
  });
}
