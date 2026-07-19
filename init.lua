package.loaded["cfg.clipboard"] = nil
package.loaded["cfg.launcher"] = nil
package.loaded["modules.clipboard"] = nil
package.loaded["modules.launcher"] = nil
package.loaded["cfg.cockpit"] = nil
package.loaded["modules.cockpit"] = nil
package.loaded["modules.projects"] = nil
package.loaded["modules.ai_sessions"] = nil
package.loaded["modules.git"] = nil
package.loaded["modules.git.providers"] = nil
package.loaded["modules.workspaces.cmux"] = nil
package.loaded["modules.workspaces"] = nil

require("config_watcher").start()

local clipboardConfig = require("cfg.clipboard")
local launcherConfig = require("cfg.launcher")
local clipboardModule = require("modules.clipboard")
local launcherModule = require("modules.launcher")
local cockpitConfig = require("cfg.cockpit")
local cockpitOk, cockpitModule = pcall(require, "modules.cockpit")

clipboardModule.start(clipboardConfig)
launcherModule.start(launcherConfig)
if cockpitOk then
	cockpitModule.start(cockpitConfig)
else
	hs.alert.show("Cockpit load error: " .. tostring(cockpitModule):sub(1, 180))
end
