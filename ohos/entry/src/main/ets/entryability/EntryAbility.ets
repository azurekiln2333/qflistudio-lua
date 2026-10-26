import {
  FlutterAbility,
  FlutterEngine,
  MethodChannel,
  MethodCall,
  MethodResult,
} from '@ohos/flutter_ohos';
import { systemShare } from '@kit.ShareKit';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { handlePickerCall, isPickerMethod } from './PickerBridge';

const CHANNEL_PLATFORM = 'qflistudio/platform';

/// 本 App 是纯离线应用：没有账号体系、没有远程协议页、不打开系统浏览器。
/// 共享内核里仍然保留 `openAgreement` / `openUrl` 两个调用点（在线产品在用），
/// 所以这里保留这两个方法名但直接返回明确的离线错误，而不是静默
/// `notImplemented`——这样上层能显示真实原因，也不会触发任何网络行为。
const OFFLINE_ONLY_CODE = 'OFFLINE_ONLY';
const OFFLINE_ONLY_MESSAGE = '离线版不提供网络功能';

export default class EntryAbility extends FlutterAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 启动遮罩消失后、Flutter 首帧渲染前，引擎初始化期间窗口会露出
    // 默认白底。窗口底色与 Flutter 的 MD3 surface 保持一致。
    try {
      const isDark = this.context.config?.colorMode ===
        ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      windowStage.getMainWindowSync().setWindowBackgroundColor(
        isDark ? '#FF111418' : '#FFF8F9FF',
      );
    } catch (e) {
      // 设置失败不影响启动（仅深色模式可能出现短暂白闪）。
    }
    super.onWindowStageCreate(windowStage);
  }

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)

    const abilityContext = this.context as common.UIAbilityContext;

    // 通用平台能力。离线版只保留本地操作：文件选择、系统分享、启动进度。
    const platformChannel = new MethodChannel(
      flutterEngine.dartExecutor.getBinaryMessenger(),
      CHANNEL_PLATFORM,
    );
    platformChannel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult): void {
        if (call.method === 'openAgreement') {
          // 离线版不加载远程协议页，也不 push 任何内嵌 Web 路由。
          result.error(OFFLINE_ONLY_CODE, OFFLINE_ONLY_MESSAGE, null);
        } else if (call.method === 'startupProgress') {
          const progress = call.argument('progress') as number;
          if (typeof progress === 'number' && Number.isFinite(progress)) {
            abilityContext.eventHub.emit('EVENT_STARTUP_PROGRESS', Math.max(0, Math.min(1, progress)));
            result.success(null);
          } else {
            result.error('INVALID_PROGRESS', 'Startup progress must be a number', null);
          }
        } else if (call.method === 'openUrl') {
          // 离线版不调用 startAbility / viewData，不打开系统浏览器。
          result.error(OFFLINE_ONLY_CODE, OFFLINE_ONLY_MESSAGE, null);
        } else if (call.method === 'shareText') {
          // 系统分享面板（Share Kit）：纯文本分享，本地能力。
          const title = call.argument('title') as string;
          const text = call.argument('text') as string;
          const record: systemShare.SharedRecord = {
            utd: 'general.plain-text',
            content: text,
            title: title,
          };
          const data = new systemShare.SharedData(record);
          const controller = new systemShare.ShareController(data);
          const options: systemShare.ShareControllerOptions = {};
          controller.show(abilityContext, options)
            .then(() => {
              result.success(null);
            })
            .catch((err: BusinessError) => {
              result.error('SHARE_FAILED', `${err.code}: ${err.message}`, null);
            });
        } else if (isPickerMethod(call.method)) {
          handlePickerCall(abilityContext, call, result);
        } else {
          result.notImplemented();
        }
      },
    });
  }
}
