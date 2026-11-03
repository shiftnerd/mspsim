-- Where a character file lives: sprites/<group>/<name>.aseprite
--   staff    the cast and the player people (office_*, site_*, casual_*, sales_*)
--   clients  client_* (the people at the client sites)
--   expo     expo_* (the Rodent Nation conference crowd and vendors)
--   custom   custom_intern_* (the character creator hairstyles)
-- Usage: local SP = dofile(TOOLS .. "sprite_path.lua"); SP(root, "office_intern_right_anim") -> full path
return function(root, name)
  local g = name:match("^(%a+)_")
  local dir = ({client = "clients", expo = "expo", custom = "custom"})[g] or "staff"
  return root .. "sprites/" .. dir .. "/" .. name .. ".aseprite"
end
