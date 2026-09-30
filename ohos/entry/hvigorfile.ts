
import { hvigor, HvigorPlugin } from '@ohos/hvigor';
import { hapTasks, OhosHapContext, OhosPluginId } from '@ohos/hvigor-ohos-plugin';

const luaTargetAbiPlugin: HvigorPlugin = {
    pluginId: 'qfli-lua-target-abi',
    apply(node) {
        const targetPlatforms = hvigor.getParameter().getExtParam('TARGET_PLATFORM');
        if (!targetPlatforms) {
            return;
        }
        const abiFilters = targetPlatforms.split(',').map(platform => {
            switch (platform) {
                case 'ohos-arm64': return 'arm64-v8a';
                case 'ohos-x64': return 'x86_64';
                default: throw new Error(`Unsupported Flutter target platform: ${platform}`);
            }
        });
        node.afterNodeEvaluate(evaluatedNode => {
            const context = evaluatedNode.getContext(OhosPluginId.OHOS_HAP_PLUGIN) as OhosHapContext;
            const profile = context.getBuildProfileOpt();
            profile.buildOption = {
                ...profile.buildOption,
                externalNativeOptions: {
                    ...profile.buildOption?.externalNativeOptions,
                    abiFilters,
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
