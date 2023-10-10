DEBUG = false

logger = set_lua_logger("swipe.main")

local function getReactorOrDie(name)
	local r = reactorController:getReactorByName(name)
	if not r then
		error("Cannot find reactor '" .. tostring(name) .. "'")
	end
	return r
end

local scene = getReactorOrDie("Scene")
scene.node:getOrCreateStateSet():setAttribute(osg.CullFace(osg.CullFace.BACK))
scene.node:getOrCreateStateSet():setMode(GLenum.GL_LIGHTING, osg.StateAttribute.OFF)
scene.node:getOrCreateStateSet():setMode(GLenum.GL_LIGHT0, osg.StateAttribute.OFF)



-- Fill config


-- Menu event/actions
local STATE_MENU STATE_INFO = 1, 2


local menu				= getReactorOrDie("Menu")
local btn_information	= getReactorOrDie("Button_information")
local page_info		    = getReactorOrDie("Information")
local btn_back          = getReactorOrDie("Button_back")

local MASK_VIS_CLICK = bit_or(NodeReactor.Mask.VISIBLE, NodeReactor.Mask.CLICKABLE)

-- initial state
local appState = STATE_MENU
menu:show(MASK_VIS_CLICK)
page_info:hide(0x0)


-- Corousel setup
require "corousel.lua"

local corousel_ctrl_reactror = getReactorOrDie("corousel")
local corousel = Corousel(corousel_ctrl_reactror)






-- events/actions

btn_information:subscribeEvent("onDown", function()
	platform:vibrate(30)
	menu:hide(0x0)
	
	page_info:show(MASK_VIS_CLICK)
	appState = STATE_INFO
	corousel:init()
	corousel:enable()
end)

btn_back:subscribeEvent("onDown", function()
	platform:vibrate(30)
	page_info:hide(0x0)
	corousel:disable()
	

	menu:show(MASK_VIS_CLICK)
	appState = STATE_MENU
end)




-- Link button
local link = reactorController:getReactorByName("Button_download")
local system = reactorController:getReactorByName("System")

link:subscribeEvent("onClick", function()
	system:openLink("https://evtoolbox.ru")
end)
