
import { hvigor, HvigorPlugin } from '@ohos/hvigor';
import { hapTasks, OhosHapContext, OhosPluginId } from '@ohos/hvigor-ohos-plugin';

const luaTargetAbiPlugin: HvigorPlugin = {
    pluginId: 'qfli-lua-target-abi',
    apply(node) {
        const targetPlatforms = hvigor.getParameter().getExtParam('TARGET_PLATFORM');
        // IDE/default builds retain the ordinary ARM64 package. Explicit
        // Flutter targets also support x64 for real emulator validation.
        const platforms = targetPlatforms ? targetPlatforms.split(',') : ['ohos-arm64'];
        const abiFilters = platforms.map(platform => {
            switch (platform) {
                case 'ohos-arm64': return 'arm64-v8a';
                case 'ohos-x64': return 'x86_64';
                default: throw new Error(`Unsupported Flutter target platform: ${platform}`);
            }
        });
        const excludes = ['armeabi-v7a/**'];
        if (!abiFilters.includes('arm64-v8a')) excludes.push('arm64-v8a/**');
        if (!abiFilters.includes('x86_64')) excludes.push('x86_64/**');
        node.afterNodeEvaluate(evaluatedNode => {
            const context = evaluatedNode.getContext(OhosPluginId.OHOS_HAP_PLUGIN) as OhosHapContext;
            const profile = context.getBuildProfileOpt();
            profile.buildOption = {
                ...profile.buildOption,
                externalNativeOptions: {
                    ...profile.buildOption?.externalNativeOptions,
                    abiFilters,
                },
                nativeLib: {
                    ...profile.buildOption?.nativeLib,
                    filter: {
                        ...profile.buildOption?.nativeLib?.filter,
                        excludes,
                    },
                },
            };
            context.setBuildProfileOpt(profile);
        });
    },
};

export default {
    system: hapTasks,  /* Built-in plugin of Hvigor. It cannot be modified. */
    plugins: [luaTargetAbiPlugin]
}
