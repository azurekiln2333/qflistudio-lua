# Lua Git 远端绑定

日期：2026-10-16。用户明确要求绑定以下五个仓库并推送；此授权扩展此前规划中的「不 push」限制，仅针对当前 Lua 仓库的 Git 同步操作。上架产品实施仍按原规划门禁处理。

本地仓库：D:/MyNewProjects/qfli_lua，分支 main。

| Remote | URL |
| --- | --- |
| origin | https://gitlab.com/azurekiln-team/qflistudio-lua.git |
| gitee | https://gitee.com/azurekiln/qflistudio-lua.git |
| cnb | https://cnb.cool/azurekiln/qflistudio-lua |
| github | https://github.com/azurekiln2333/qflistudio-lua.git |
| gitcode | https://gitcode.com/azurekiln/qflistudio-lua.git |

绑定前没有任何 Git remote。五个地址的非交互 ls-remote 检查均返回成功，未返回 HEAD/main/master 分支引用。已按表逐项配置独立远端，origin 作为主上游。

GitLab 的 HTTPS 推送缺少非交互凭据，本机 SSH 已认证为 azurekiln。因此 origin 保留用户给出的 HTTPS fetch URL，push URL 设置为 git@gitlab.com:azurekiln-team/qflistudio-lua.git；其他四站继续使用表中 HTTPS URL。

首轮五站 main 均成功新建并推送到 1ff07e17c4f69d4a826d6d69e604ead3e5481cbc；四个 HTTPS 站点已通过独立 ls-remote 核对该对象，GitLab SSH 推送成功且本地 main 已设置跟踪 origin/main。本记录提交后再次同步全部五站，并逐一核对远端最终 main 与本地 HEAD。

同步对象是已提交的 main；工作区原有未提交修改保留。使用普通快进/新分支推送，逐个记录认证或服务器拒绝结果；成功后再次读取远端 main 的对象 ID，与本地 HEAD 对比验证。若某个站点拒绝，继续处理其余独立站点，不执行强制推送。

后续单站同步：git push origin main、git push gitee main、git push cnb main、git push github main、git push gitcode main。凭据由现有 Git credential helper 管理，不写入 remote URL 或本记录。
