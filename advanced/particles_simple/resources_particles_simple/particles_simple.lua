-------------------------------------------------------------------------------
--                                                                           --
-- Copyright 2019 EligoVision. Interactive Technologies                      --
--                                                                           --
-- Permission is hereby granted, free of charge, to any person obtaining a   --
-- copy of this software and associated documentation files                  --
-- (the "Software"), to deal in the Software without restriction, including  --
-- without limitation the rights to use, copy, modify, merge, publish,       --
-- distribute, sublicense, and/or sell copies of the Software, and to permit --
-- persons to whom the Software is furnished to do so, subject to the        --
-- following conditions:                                                     --
--                                                                           --
-- The above copyright notice and this permission notice shall be included   --
-- in all copies or substantial portions of the Software.                    --
--                                                                           --
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS   --
-- OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF                --
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.    --
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY      --
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,      --
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE         --
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                    --
--                                                                           --
-------------------------------------------------------------------------------

-- EV Toolbox 3.4.x

local transform1 = reactorController:getReactorByName("Transform_fire1")
local transform2 = reactorController:getReactorByName("Transform_fire2")

--Задаем шаблон частиц
local template = osgParticle.Particle()
template:setLifeTime(1.75)
template:setSizeRange(0.03, 0.10)
template:setMass(1000.0)

local function createParticlesSystem(filename)
	--Создаем систему частиц
	local system = osgParticle.ParticleSystem()
	system:setDefaultParticleTemplate(template)
	system:setDefaultAttributes("resources/" .. filename, true, false, 0)
	system:getOrCreateStateSet():setDefine("EV_GL_OPACITY_FROM_DIFFUSE", osg.StateAttribute.ON)
	system:getOrCreateStateSet():setAttributeAndModes(osg.AlphaFunc(osg.AlphaFunc.GREATER, 0.05))

	local shooter = osgParticle.RadialShooter()
	shooter:setInitialSpeedRange(0.1, 0.8)

	--Создаем источник частиц
	local emitter = osgParticle.ModularEmitter()
	emitter:setParticleSystem(system)
	emitter:setShooter(shooter)

	local randomCounter = osgParticle.RandomRateCounter()
	randomCounter:setRateRange(50, 300)
	emitter:setCounter(randomCounter)

	return system, emitter
end

local system1, emitter1 = createParticlesSystem("fire.png")
local system2, emitter2 = createParticlesSystem("fire3.png")

local updater = osgParticle.ParticleSystemUpdater()
updater:addParticleSystem(system1)
updater:addParticleSystem(system2)
sceneRoot:addChild(updater)


transform1.node:addChild(system1)
transform1.node:addChild(emitter1)

transform2.node:addChild(system2)
transform2.node:addChild(emitter2)
