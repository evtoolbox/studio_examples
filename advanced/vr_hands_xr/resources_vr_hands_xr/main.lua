-------------------------------------------------------------------------------
--                                                                           --
-- Copyright 2025 EligoVision. Interactive Technologies                      --
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

local logger = set_lua_logger("ev_studio.examples.vr_hands_xr")

local scene				= reactorController:getReactorByName("Scene")
local left_hand			= reactorController:getReactorByName("vr_hand_left")
local left_hand_rig		= reactorController:getReactorByName("vr_hand_left/rig")
local right_hand		= reactorController:getReactorByName("vr_hand_right")
local right_hand_rig	= reactorController:getReactorByName("vr_hand_right/rig")


-- Graphics tuning (+ helper functions)

local sceneStateSet = scene.node:getOrCreateStateSet()
sceneStateSet:setAttributeAndModes(osg.CullFace(osg.CullFace.BACK))

local function customizeHandNode(aController)
	local node = aController.node
	local ss = node:getOrCreateStateSet()

	local visibilityUniform = ss:getOrCreateUniform("ev_Visibility", osg.Uniform.FLOAT)
	visibilityUniform:setDataVariance(osg.Object.DYNAMIC)
	visibilityUniform:setFloat(0.75)
	ss:setMode(GLenum.GL_BLEND, osg.StateAttribute.ON)
	ss:setRenderingHint(osg.StateSet.TRANSPARENT_BIN)

	-- NOTE: Working on DrawThreadPerContext (default) and SingleThreaded (default on Helmets)
	-- Prevent ugly transparency
	local ss1 = osg.StateSet()
	ss1:setAttributeAndModes(osg.ColorMask(false, false, false, false))
	ss1:setAttributeAndModes(osg.Depth(osg.Depth.LESS, 0.0, 1.0, true))

	local ss2 = osg.StateSet()
	ss2:setAttributeAndModes(osg.ColorMask(true, true, true, true))
	ss2:setAttributeAndModes(osg.Depth(osg.Depth.EQUAL, 0.0, 1.0, false))

	node:setCullCallback(osg.NodeCallback(function(node, nv)
		local cv = cast(nv, osgUtil.CullVisitor)	-- TODO: asCullVisitor
		cv:pushStateSet(ss1)
		node:traverse(cv)
		cv:popStateSet()
		cv:pushStateSet(ss2)
		node:traverse(cv)
		cv:popStateSet()

		return true
	end))
end

local function disableRigCulling(node)
	local visitor = osg.NodeVisitor(osg.NodeVisitor.TRAVERSE_ALL_CHILDREN)
	visitor:setTraversalMask(0xffffffff)
	visitor:setNodeMaskOverride(0xffffffff)

	visitor:setApplyGeometryCb(function(node)
		if node:className() == "RigGeometryGPU" then
			logger:warn("Disable culling of '", node:getName(), "'")
			node:setCullingActive(false)
		end
		return true
	end)

	node:accept(visitor)
end

customizeHandNode(left_hand_rig)
disableRigCulling(left_hand_rig.node)

customizeHandNode(right_hand_rig)
disableRigCulling(right_hand_rig.node)


-- Hands setup

local xrHandJoints =
{
	{ xrIndex = 0		, name = "Palm"					}	-- XR_HAND_JOINT_PALM_EXT
,	{ xrIndex = 1		, name = "Wrist"				}	-- XR_HAND_JOINT_WRIST_EXT
,	{ xrIndex = 2		, name = "Thumb_Metacarpal"		}	-- XR_HAND_JOINT_THUMB_METACARPAL_EXT
,	{ xrIndex = 3		, name = "Thumb_Proximal"		}	-- XR_HAND_JOINT_THUMB_PROXIMAL_EXT
,	{ xrIndex = 4		, name = "Thumb_Distal"			}	-- XR_HAND_JOINT_THUMB_DISTAL_EXT
,	{ xrIndex = 5		, name = "Thumb_Tip"			}	-- XR_HAND_JOINT_THUMB_TIP_EXT
,	{ xrIndex = 6		, name = "Index_Metacarpal"		}	-- XR_HAND_JOINT_INDEX_METACARPAL_EXT
,	{ xrIndex = 7		, name = "Index_Proximal"		}	-- XR_HAND_JOINT_INDEX_PROXIMAL_EXT
,	{ xrIndex = 8		, name = "Index_Intermediate"	}	-- XR_HAND_JOINT_INDEX_INTERMEDIATE_EXT
,	{ xrIndex = 9		, name = "Index_Distal"			}	-- XR_HAND_JOINT_INDEX_DISTAL_EXT
,	{ xrIndex = 10		, name = "Index_Tip"			}	-- XR_HAND_JOINT_INDEX_TIP_EXT
,	{ xrIndex = 11		, name = "Middle_Metacarpal"	}	-- XR_HAND_JOINT_MIDDLE_METACARPAL_EXT
,	{ xrIndex = 12		, name = "Middle_Proximal"		}	-- XR_HAND_JOINT_MIDDLE_PROXIMAL_EXT
,	{ xrIndex = 13		, name = "Middle_Intermediate"	}	-- XR_HAND_JOINT_MIDDLE_INTERMEDIATE_EXT
,	{ xrIndex = 14		, name = "Middle_Distal"		}	-- XR_HAND_JOINT_MIDDLE_DISTAL_EXT
,	{ xrIndex = 15		, name = "Middle_Tip"			}	-- XR_HAND_JOINT_MIDDLE_TIP_EXT
,	{ xrIndex = 16		, name = "Ring_Metacarpal"		}	-- XR_HAND_JOINT_RING_METACARPAL_EXT
,	{ xrIndex = 17		, name = "Ring_Proximal"		}	-- XR_HAND_JOINT_RING_PROXIMAL_EXT
,	{ xrIndex = 18		, name = "Ring_Intermediate"	}	-- XR_HAND_JOINT_RING_INTERMEDIATE_EXT
,	{ xrIndex = 19		, name = "Ring_Distal"			}	-- XR_HAND_JOINT_RING_DISTAL_EXT
,	{ xrIndex = 20		, name = "Ring_Tip"				}	-- XR_HAND_JOINT_RING_TIP_EXT
,	{ xrIndex = 21		, name = "Little_Metacarpal"	}	-- XR_HAND_JOINT_LITTLE_METACARPAL_EXT
,	{ xrIndex = 22		, name = "Little_Proximal"		}	-- XR_HAND_JOINT_LITTLE_PROXIMAL_EXT
,	{ xrIndex = 23		, name = "Little_Intermediate"	}	-- XR_HAND_JOINT_LITTLE_INTERMEDIATE_EXT
,	{ xrIndex = 24		, name = "Little_Distal"		}	-- XR_HAND_JOINT_LITTLE_DISTAL_EXT
,	{ xrIndex = 25		, name = "Little_Tip"			}	-- XR_HAND_JOINT_LITTLE_TIP_EXT
-- ,	{ xrIndex = 0x7FFFFFFF 								}	-- XR_HAND_JOINT_MAX_ENUM_EXT
}

local function createDrawable(shape)
	local drawable = osg.ShapeDrawable(shape)
	drawable:setColorArray(nil)
	drawable:setUseVertexBufferObjects(true)
	drawable:setUseVertexArrayObject(true)
	-- optimizer:optimize(drawable)

	return drawable
end

-- Sphere
local sphereRadius = 0.002
local sphereDrawable = createDrawable(osg.Sphere(osg.Vec3(0.0, 0.0, 0.0), sphereRadius))
local sphereShape = bt.SphereShape(sphereRadius)

sphereDrawable:getOrCreateStateSet():addUniform(osg.Uniform.Vec4f("ev_MaterialDiffuse", osg.Vec4(0.0, 0.5, 1.0, 1.0)))
sphereDrawable:getOrCreateStateSet():addUniform(osg.Uniform.Vec4f("ev_MaterialAmbient", osg.Vec4(0.0, 0.5, 1.0, 1.0)))
sphereDrawable:setNodeMask(NodeReactor.Mask.VISIBLE)


-- local E = osg.Matrix.identity()

local jointBones_L		= {}
local jointBones_R		= {}
local jointTransforms_L	= {}
local jointTransforms_R	= {}

local XR_SPACE_LOCATION_ORIENTATION_TRACKED_BIT		= 0x00000004
local XR_SPACE_LOCATION_POSITION_TRACKED_BIT		= 0x00000008

-- Helper function to add reactor and bone to the tables
local function addBone(key, boneName, modelWithSkeleton, reactorTbl, bonesTbl)
	local jointReactor = reactorController:getReactorByName(boneName)
	if jointReactor then
		jointReactor.node:addChild(sphereDrawable)
		reactorTbl[key] = jointReactor
	end

	local bone = cast(EVosgUtil.findNamedClassNode(boneName, modelWithSkeleton, "Bone"), osgAnimation.Bone)
	if bone then
		logger:info("Bone '" .. boneName .. "' found!")
		bonesTbl[key] = bone
		bone:setUpdateCallback(nil)		-- NOTE: remove default callback from the bone
		-- bone:setMatrix(E)
	end
end

-- Fill joint tables
for _, v in pairs(xrHandJoints) do
	addBone(v.xrIndex, v.name .. "_L", left_hand_rig.node, jointTransforms_L, jointBones_L)		-- Left hand skeleton (rig geometry) and reactors
	addBone(v.xrIndex, v.name .. "_R", right_hand_rig.node, jointTransforms_R, jointBones_R)	-- Right hand skeleton (rig geometry) and reactors
end

vrHeadset:subscribe("ControllerMotionEvent", function(_, aControllerType, aExtraData)
	local jointBones
	local jointTransforms

	if aControllerType == DeviceType.HAND_LEFT then
		jointTransforms	= jointTransforms_L
		jointBones		= jointBones_L
	elseif aControllerType == DeviceType.HAND_RIGHT then
		jointTransforms = jointTransforms_R
		jointBones		= jointBones_R
	else
		return
	end

	if not aExtraData or not aExtraData.xr then
		logger:error("No data for hand presented")
		return
	end

	local joints = aExtraData.xr.handJoints

	for k, v in pairs(xrHandJoints) do
		local jt, jb = jointTransforms[v.xrIndex], jointBones[v.xrIndex]
		if jt or jb then
			local handJ = joints:at(v.xrIndex)

			-- local locationFlags = handJ:locationFlags()
			-- if (bit_and(locationFlags, XR_SPACE_LOCATION_ORIENTATION_TRACKED_BIT) == 0 or bit_and(locationFlags, XR_SPACE_LOCATION_POSITION_TRACKED_BIT) == 0) then
			-- 	if aControllerType == DeviceType.HAND_LEFT then left_hand:hide() end
			-- 	if aControllerType == DeviceType.HAND_RIGHT then right_hand:hide() end
			-- 	return
			-- else
			-- 	if aControllerType == DeviceType.HAND_LEFT then left_hand:show() end
			-- 	if aControllerType == DeviceType.HAND_RIGHT then right_hand:show() end
			-- end

			local pose = handJ:pose()
			local mat = xr.xr2osg(pose)
			-- local position = pose:position()
			-- logger:info(v.xrIndex, ": ", position:x(), ", ", position:y(), ", ", position:z())

			if jt then	-- transform reactor
				jt.node:setMatrix(mat)
			end

			if jb then	-- skeleton's bone
				jb:setMatrixInSkeletonSpace(mat)
			end
		end
	end
end)
