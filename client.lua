--[[
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
--]]

-- Created by Jamelele

-- Do NOT edit this file unless you know what you're doing.
-- If you're looking to edit the configuration, go to config.lua

-- DO NOT CHANGE ANY OF THESE VALUES! Go to config.lua for configuration.
-- DO NOT CHANGE ANY OF THESE VALUES! Go to config.lua for configuration.
-- DO NOT CHANGE ANY OF THESE VALUES! Go to config.lua for configuration.

local config = config
local enabled = true
local active = false
local ped = nil -- Cache the ped
local currentPedData = nil -- Config data for the current ped
local weapons = { }

function table_invert(t)
  local s={}
  for k,v in pairs(t) do
    s[v]=k
  end
  return s
end

function drawNotification(text)
  SetNotificationTextEntry("STRING")
  AddTextComponentSubstringPlayerName(text)
  DrawNotification(false, false)
end

-- Returns if the given weapon (hash) is in the config
function isConfigWeapon(weapon)
  return weapons[weapon] ~= nil
end

local function loadWeapon(weapon)
  if not tonumber(weapon) then -- If not already a hash
    weapon = GetHashKey(weapon)
  end
  if isConfigWeapon(weapon) then return end -- Don't add duplicate weapons
  weapons[weapon] = true
end

if type(config.weapon) == 'table' then
  for _, weapon in ipairs(config.weapon) do
    loadWeapon(weapon)
  end
else
  loadWeapon(config.weapon)
end

-- Slow loop to determine the player ped and if it is of interest to the algorithm
Citizen.CreateThread(function()
  while true do
    ped = GetPlayerPed(-1)
    local ped_hash = GetEntityModel(ped)
    local enable = false -- We updated the 'enabled' variable in the upper scope with this at the end
    -- Loop over peds in the config
    for config_ped, data in pairs(config.peds) do
      if GetHashKey(config_ped) == ped_hash then 
        enable = true -- By default, the ped will have its holsters enabled
        if data.enabled ~= nil then -- Optional 'enabled' option
          enable = data.enabled
        end
        currentPedData = data
        break
      end
    end
    active = enable
    Citizen.Wait(5000)
  end
end)

-- Faster loop to change holster textures
local last_weapon = nil -- Variable used to save the weapon from the last tick
Citizen.CreateThread(function()
  while true do
    if active and enabled then -- A ped in the config is in use, so we start checking
      current_weapon = GetSelectedPedWeapon(ped)
      if current_weapon ~= last_weapon then -- The weapon in hand has changed, so we need to check for holsters
        for component, holsters in pairs(currentPedData.components) do
          local holsterDrawable = GetPedDrawableVariation(ped, component) -- Current drawable of this component
          local holsterTexture = GetPedTextureVariation(ped, component) -- Current texture, we need to preserve this

          local emptyHolster = holsters[holsterDrawable] -- The corresponding empty holster
          if emptyHolster and isConfigWeapon(current_weapon) then
            SetPedComponentVariation(ped, component, emptyHolster, holsterTexture, 0)
            break
          end

          local filledHolster = table_invert(holsters)[holsterDrawable] -- The corresponding filled holster
          if filledHolster and not isConfigWeapon(current_weapon) then
            SetPedComponentVariation(ped, component, filledHolster, holsterTexture, 0)
            break
          end
        end
      end
      last_weapon = current_weapon
    end
    Citizen.Wait(200)
  end
end)

local messages = {
  [true] = 'Dynamic holsters enabled',
  [false] = 'Dynamic holsters disabled'
}

RegisterCommand('holsters', function(source, args)
  if not args[1] then
    enabled = not enabled
  end

  if args[1] == 'on' then
    enabled = true
  elseif args[1] == 'off' then
    enabled = false
  end

  drawNotification('~p~' .. messages[enabled])
end, false)
