-- Создание одной переменной для 2х манипуляторов камеры с выбором работы
local manipulatorName = (evi.os() == "android" or evi.os() == "ios") and "multitouch" or "trackball"
local manipulator = reactorController:getReactorByName(manipulatorName).manipulator

local function getReactorOrDie(name)
	local reactor = reactorController:getReactorByName(name)
	if not reactor then
		error("Cannot find reactor '" .. tostring(name) .."'")
	end

	return reactor
end


local models = {"fox", "deer"}


-- Реализация поворота и масштабирования моделей на метках
for _, v in pairs(models) do
	local model = getReactorOrDie("Transform_" .. v)
	local marker = getReactorOrDie("Marker_" .. v)
	marker:subscribeEvent("onEntered", function()
			manipulator:home(0.0)
		end)

	local initialScale = model.scale
	model.node:setUpdateCallback(osg.NodeCallback(function ( ... )
		-- body
		local d = manipulator:getDistance()
		local h = manipulator:getHeading()
		model.scale = initialScale / d
		model.rotate = osg.Vec3(0.0, 0.0, h*(-180.0)/math.pi)


		return true
		


	end))

end


-- Добавление вьювера для работы манипулятора камеры
viewer:addEventHandler(manipulator)
manipulator:setAllowThrow(false)
