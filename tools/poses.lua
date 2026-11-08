-- Pose fields (all angles in degrees, positive = toward the facing side):
--   bob, crouch, lean, rx, ry, hx, hy, hrot (head tilt), rotBody, ry2, ground, flash, face, dur
--   aN/aF = near/far arm (upper), aNr/aFr = elbow bend relative to the upper arm (positive = hand forward/up)
--   lN/lF = near/far leg (thigh), lNr/lFr = knee bend relative to the thigh (negative = shin swings back)
--   lNl/lFl = extra foot lift in px
local poses, tags = {}, {}
local function add(tag, list)
  local a = #poses + 1
  for _, p in ipairs(list) do poses[#poses + 1] = p end
  tags[#tags + 1] = {tag, a, #poses}
end

add("idle", {
  {dur = 500},
  {bob = 1, dur = 320},
  {bob = 1, face = "blink", dur = 120},
  {bob = 1, dur = 320},
})

-- walk: legs bend at the knee, back foot lifts its heel at toe-off, elbows bend a little
local function w(lN, lNr, lF, lFr, aN, aF, bob)
  return {lN = lN, lNr = lNr, lF = lF, lFr = lFr, aN = aN, aNr = 12, aF = aF, aFr = 12, bob = bob, lean = 1, dur = 90}
end
add("walk", {
  w(30, 0, -22, -35, -20, 14, 1),    -- contact: near foot planted, far heel lifting
  w(12, 0, -14, -30, -10, 8, 1),
  w(0, 0, 10, -50, 0, 0, 0),         -- passing: far knee bent, foot swinging through
  w(-12, 0, 26, -15, 12, -8, 0),
  w(-22, -30, 30, 0, 14, -14, 1),    -- contact: far foot planted, near heel lifting
  w(-14, -30, 12, 0, 8, -10, 1),
  w(10, -50, 0, 0, 0, 0, 0),
  w(26, -15, -12, 0, -8, 12, 0),
})

-- run: forearms pumped, heels kicked up, forward lean, two flight frames
local function r(lN, lNr, lF, lFr, aN, aNr, aF, aFr, ry, bob)
  local p = {lN = lN, lNr = lNr, lF = lF, lFr = lFr, aN = aN, aNr = aNr, aF = aF, aFr = aFr,
             lean = 3, hx = 1, bob = bob or 1, dur = 70}
  if ry then p.ry = ry; p.ground = false end
  return p
end
add("run", {
  r(40, -15, -30, -75, -40, 35, 45, 75),
  r(15, -5, -18, -55, -30, 30, 28, 45),
  r(-25, -60, 45, -20, 35, 45, -45, 25, -3, 0),
  r(-30, -75, 40, -15, 45, 75, -40, 35),
  r(-18, -55, 15, -5, 28, 45, -30, 30),
  r(45, -20, -25, -60, -45, 25, 35, 45, -3, 0),
})

-- jump: raised arms stay beside the head (a forward-raised near arm crosses the face)
add("jump", {
  {crouch = 3, lean = 1, aN = -35, aNr = 10, aF = -35, aFr = 10, lN = 10, lNr = -15, lF = 10, lFr = -15, dur = 140},
  {ry = -4, ground = false, lean = 1, lN = -6, lNl = 2, lF = -6, lFl = 3, aN = -40, aNr = 20, aF = 150, dur = 80},
  {ry = -12, ground = false, lN = 75, lNr = -105, lF = 62, lFr = -95, aN = -45, aNr = 25, aF = 135, aFr = 15, dur = 130},
  {ry = -6, ground = false, lN = 12, lNr = -10, lF = -8, lFr = -5, aN = -25, aNr = 20, aF = 80, aFr = 20, dur = 100},
})

add("land", {
  {crouch = 4, lean = 2, aN = 45, aNr = 10, aF = 50, aFr = 10, lN = 8, lNr = -12, lF = 8, lFr = -12, dur = 90},
  {crouch = 2, lean = 1, aN = 20, aF = 20, dur = 90},
  {dur = 110},
})

add("hurt", {
  {face = "hurt", flash = 0.7, lean = -3, rx = -2, hx = -2, hrot = -10, aN = -25, aNr = 10, aF = 30, aFr = 10, lN = -6, lF = 8, dur = 80},
  {face = "hurt", lean = -4, rx = -3, hx = -1, hrot = -8, aN = -20, aNr = 10, aF = 25, aFr = 10, lN = -6, lF = 8, dur = 120},
  {face = "hurt", lean = -2, rx = -1, hrot = -4, aN = -8, aF = 8, dur = 110},
})

-- death: hit, stagger, knees buckle, topple, bounce, settle limp (limbs stay bent while rotated)
add("death", {
  {face = "hurt", flash = 0.7, lean = -3, rx = -2, hx = -2, hrot = -10, aN = -25, aNr = 10, aF = 30, aFr = 10, lN = -6, lF = 8, dur = 80},
  {face = "hurt", crouch = 2, lean = -6, rx = -3, hrot = -12, aN = -60, aNr = 20, aF = 70, aFr = 30, lN = -4, lNr = -35, lF = 6, lFr = -30, dur = 100},
  {face = "hurt", rotBody = 14, lean = -8, rx = -5, hrot = -15, aN = -80, aNr = 10, aF = 95, aFr = 15, lN = 25, lNr = -50, lF = 20, lFr = -45, ground = false, dur = 80},
  {face = "hurt", rotBody = 42, rx = -5, hrot = -10, aN = -100, aNr = 10, aF = 110, aFr = 10, lN = 30, lNr = -30, lF = 15, lFr = -20, ground = false, dur = 80},
  {face = "hurt", rotBody = 74, rx = -5, hrot = -12, aN = -120, aF = 130, aFr = 10, lN = 20, lNr = -25, lF = 8, lFr = -15, ground = false, dur = 80},
  {face = "hurt", rotBody = 90, rx = -5, hrot = -12, aN = -110, aNr = 15, aF = 100, aFr = 15, lN = 14, lNr = -20, lF = 6, lFr = -12, ground = false, ry2 = -2, dur = 90},
  {face = "hurt", rotBody = 90, rx = -5, hrot = -14, aN = -100, aNr = 20, aF = 40, aFr = 70, lN = 8, lNr = -10, lF = -4, lFr = 0, ground = false, dur = 600},
})

-- seated: the thigh runs forward (a hair above horizontal), the knee bends and the shin drops straight down so both shoes stand flat on the
-- floor row. The body (hips, belt, torso, arms, head) is exactly where the old straight-shin sit put it: `legRef` is the old leg setup
-- (kn 60, thigh 85 / 80, shin straight down) the engine measures the ground with, `floor` then moves each leg so its sole is on that row,
-- `legDy` lifts the thighs 3 px off the pelvis block so a shin shows under them, lNx / lFx slide the hip pivots forward (the near leg starts
-- behind the far one, 9 px apart in the still) so both knees clear the pelvis block and the near foot ends up a little behind the far one.
local SEAT_LIFT, SEAT_SHIN = 6, 4
local SEAT_REF = {kn = 60, lN = 85, lNr = -85, lF = 80, lFr = -80}
local function seat(extra)
  local p = {kn = 55, legDy = -3, lNx = 8, lFx = 3, lN = 90, lNr = -90, lF = 88, lFr = -88, legRef = SEAT_REF, floor = true,
             bob = 4, aN = 60, aNr = 25, aF = 65, aFr = 22, dur = 120,
             lift = SEAT_LIFT, shin = SEAT_SHIN, keepN = true, keepF = true, leanAdd = 2, armLen = 2}
  for k, v in pairs(extra or {}) do p[k] = v end
  return p
end
local function relaxed(extra)
  return seat(extra and {aN = 20, aNr = 60, aF = 25, aFr = 65, dur = extra.dur or 120} or {aN = 20, aNr = 60, aF = 25, aFr = 65})
end
add("sitdown", {
  {kn = 57, lN = 45, lNr = -45, lF = 42, lFr = -42, lean = 1, aN = 10, aNr = 30, aF = 12, aFr = 30, dur = 110},
  relaxed({dur = 120}),
})
-- sit: a visible breath (the shoulders settle a pixel, the head sags a pixel more and the near hand slides), never a still frame
add("sit", {
  relaxed({dur = 900}),
  seat({aN = 24, aNr = 56, aF = 25, aFr = 65, bob = 5, hy = 1, dur = 700}),
})
add("type", {
  seat({aNr = 20, aFr = 30, dur = 150}),
  seat({aNr = 32, aFr = 16, dur = 150}),
  seat({aNr = 26, aFr = 24, hy = 0, dur = 150}),
})

-- interaction poses: reach out with the far arm (using a prop), wave hello (loops), talk with hand gestures (loops)
add("reach", {
  {lean = 1, aF = 40, aFr = 8, aN = -10, dur = 90},
  {lean = 2, aF = 85, aFr = 4, aN = -12, dur = 330},
  {lean = 1, aF = 40, aFr = 8, aN = -10, dur = 90},
})
add("wave", {
  {aF = 140, aFr = 25, dur = 140}, {aF = 148, aFr = -5, dur = 140},
  {aF = 140, aFr = 25, dur = 140}, {aF = 148, aFr = -5, dur = 140},
})
add("talk", {
  {aF = 50, aFr = 70, aN = 10, aNr = 20, dur = 180}, {aF = 75, aFr = 40, aN = 10, aNr = 20, bob = 1, dur = 180},
  {aF = 40, aFr = 80, aN = 20, aNr = 45, dur = 180}, {aF = 60, aFr = 55, bob = 1, dur = 180},
})

-- carrying a cup: near forearm up in front of the chest (items are attached at the near hand)
local function hold(extra)
  local p = {aN = 35, aNr = 85, dur = 500}
  for k, v in pairs(extra or {}) do p[k] = v end
  return p
end
add("hold", {hold({}), hold({bob = 1, dur = 320})})
local walkStart = tags[1] and 0 or 0
for _, t in ipairs(tags) do if t[1] == "walk" then walkStart = t[2] end end
local carry = {}
for i = 0, 7 do
  local q = {}
  for k, v in pairs(poses[walkStart + i]) do q[k] = v end
  q.aN = 35; q.aNr = 85
  carry[#carry + 1] = q
end
add("walkhold", carry)
add("sip", {
  hold({aN = 56, aNr = 80, dur = 130}),
  hold({aN = 75, aNr = 53, dur = 450}),
  hold({aN = 63, aNr = 55, dur = 130}),
})

-- seated sip: the near forearm brings the cup up from the desk
add("sitsip", {
  seat({aN = 58, aNr = 75, dur = 150}),
  seat({aN = 80, aNr = 44, keepN = false, dur = 450}),
  seat({aN = 64, aNr = 63, dur = 150}),
})

-- on the phone: near forearm folded up so the hand (and the handset) sits at the ear
add("call", {
  hold({aN = 101, aNr = 120, dur = 450}),
  hold({aN = 95, aNr = 127, dur = 450}),
})
add("sitcall", {
  seat({aN = 99, aNr = 118, keepN = false, dur = 450}),
  seat({aN = 93, aNr = 125, keepN = false, dur = 450}),
})

-- dance = the robot: no bounce or sway, everything snaps between stiff poses with holds. Angles: 0 = arm hanging, 90 = pointing
-- forward, 180 = straight up; negative = swung back. Right-angle elbows (aXr = +-90), head snaps, legs stay straight.
local function robot(extra)
  local q = {dur = 200}
  for k, v in pairs(extra) do q[k] = v end
  return q
end
add("dance", {
  robot{dur = 200},                                                                              -- 1 reset
  robot{dur = 160, hrot = 12},                                                                   -- 2 head snap
  robot{dur = 200, hrot = 12, aF = 90, aFr = 0},                                                 -- 3 far arm out, stiff
  robot{dur = 240, hrot = 0, aF = 90, aFr = 90},                                                 -- 4 right angle, forearm up
  robot{dur = 240, hrot = 0, aF = 90, aFr = 90, aN = -90, aNr = -90},                            -- 5 both arms L, near one chicken-wing
  robot{dur = 240, hrot = -7, aF = 90, aFr = 90, aN = -90, aNr = -90, lN = 18, lF = -8},        -- 6 snap look, stiff step
  robot{dur = 200, hrot = 0, aF = 165, aFr = 0, aN = 0, lN = 0, lF = 0},                         -- 7 far arm straight up
  robot{dur = 200, hrot = 12, aF = 90, aFr = 0, aN = -80, aNr = 0, lN = -8, lF = 18},            -- 8 arms out front/back, step swap
  robot{dur = 240, hrot = 0, aF = 90, aFr = -90, aN = -90, aNr = 90},                            -- 9 forearms drop
  robot{dur = 200, hrot = 12, lean = -2, aF = 45, aFr = 0, aN = -45, aNr = 0},                   -- 10 lean back, arms at 45
  robot{dur = 200, hrot = -7, lean = 2, aF = 45, aFr = 0, aN = -45, aNr = 0},                   -- 11 lean forward, snap look
  robot{dur = 160, hrot = 0},                                                                    -- 12 reset
})

-- ---- seated life (frames 86+): idle gestures for people who sit (see npc.gd / player.gd `_gesture`) ----
-- The far arm is the one that goes to the head (the near arm is drawn over the face); the near arm does the desk work.
add("sitstretch", {
  seat({keepN = false, keepF = false, aN = 30, aNr = 40, aF = 60, aFr = 30, lean = -1, dur = 130}),
  seat({keepN = false, keepF = false, aN = -20, aNr = 25, aF = 120, aFr = 15, lean = -2, hrot = -6, dur = 130}),
  seat({keepN = false, keepF = false, aN = -45, aNr = 20, aF = 132, aFr = 22, lean = -3, hrot = -10, hy = -1, dur = 280}),
  seat({keepN = false, keepF = false, aN = -50, aNr = 18, aF = 138, aFr = 18, lean = -3, hrot = -12, hy = -1, dur = 450}),
  seat({keepN = false, keepF = false, aN = 0, aNr = 30, aF = 100, aFr = 25, lean = -1, hrot = -4, dur = 140}),
})
add("sitscratch", {
  seat({keepN = false, aN = 90, aNr = 60, aF = 25, aFr = 65, armTop = true, dur = 140}),
  seat({keepN = false, aN = 140, aNr = 60, aF = 25, aFr = 65, hrot = 4, armTop = true, dur = 160}),
  seat({keepN = false, aN = 148, aNr = 50, aF = 25, aFr = 65, hrot = 5, armTop = true, dur = 150}),
  seat({keepN = false, aN = 140, aNr = 62, aF = 25, aFr = 65, hrot = 3, armTop = true, dur = 150}),
  seat({keepN = false, aN = 148, aNr = 50, aF = 25, aFr = 65, hrot = 5, armTop = true, dur = 150}),
  seat({keepN = false, aN = 90, aNr = 60, aF = 25, aFr = 65, armTop = true, dur = 140}),
})
add("sitlook", {
  seat({aNr = 20, aFr = 30, hrot = -4, dur = 200}),
  seat({aNr = 20, aFr = 30, hrot = -9, hx = -1, hy = -1, dur = 420}),
  seat({aNr = 20, aFr = 30, hrot = 6, hx = -2, dur = 420}),
  seat({aNr = 20, aFr = 30, hrot = -9, hx = -1, hy = -1, face = "blink", dur = 140}),
  seat({aNr = 20, aFr = 30, hrot = -2, dur = 200}),
})
add("sityawn", {
  seat({keepN = false, aN = 20, aNr = 60, aF = 25, aFr = 65, hrot = -4, lean = -1, dur = 160}),
  seat({keepN = false, aN = 62, aNr = 85, aF = 25, aFr = 65, hrot = -9, lean = -1, face = "hurt", armTop = true, dur = 200}),
  seat({keepN = false, aN = 72, aNr = 90, aF = 25, aFr = 65, hrot = -13, lean = -2, hy = -1, face = "hurt", armTop = true, dur = 520}),
  seat({keepN = false, aN = 66, aNr = 88, aF = 25, aFr = 65, hrot = -6, lean = -1, face = "blink", armTop = true, dur = 200}),
  seat({keepN = false, aN = 20, aNr = 60, aF = 25, aFr = 65, dur = 160}),
})
add("sitslump", {
  seat({aN = 20, aNr = 60, aF = 25, aFr = 65, lean = -1, bob = 4, dur = 260}),
  seat({aN = 8, aNr = 50, aF = 12, aFr = 55, lean = 1, bob = 6, hy = 1, hrot = 10, dur = 400}),
  seat({aN = 8, aNr = 50, aF = 12, aFr = 55, lean = 1, bob = 6, hy = 1, hrot = 12, face = "blink", dur = 700}),
  seat({aN = 14, aNr = 55, aF = 18, aFr = 60, lean = -1, bob = 4, hrot = -2, dur = 300}),
})
add("sitmouse", {
  seat({aN = 52, aNr = 24, aF = 20, aFr = 60, hrot = -2, dur = 200}),
  seat({aN = 58, aNr = 22, aF = 20, aFr = 60, hrot = -2, dur = 200}),
  seat({aN = 62, aNr = 30, aF = 20, aFr = 60, hrot = -2, dur = 200}),
  seat({aN = 56, aNr = 26, aF = 20, aFr = 60, hrot = -3, dur = 200}),
})
add("sitphone", {
  seat({keepN = false, aN = 40, aNr = 60, aF = 25, aFr = 65, dur = 180}),
  seat({keepN = false, aN = 70, aNr = 100, aF = 25, aFr = 65, hrot = 8, dur = 200}),
  seat({keepN = false, aN = 74, aNr = 96, aF = 25, aFr = 65, hrot = 10, dur = 420}),
  seat({keepN = false, aN = 70, aNr = 102, aF = 25, aFr = 65, hrot = 8, dur = 420}),
  seat({keepN = false, aN = 40, aNr = 60, aF = 25, aFr = 65, dur = 180}),
})
add("sitnod", {
  relaxed({dur = 150}),
  seat({aN = 20, aNr = 60, aF = 25, aFr = 65, hrot = 9, hy = 1, dur = 150}),
  seat({aN = 20, aNr = 60, aF = 25, aFr = 65, hrot = -2, dur = 140}),
  seat({aN = 20, aNr = 60, aF = 25, aFr = 65, hrot = 9, hy = 1, dur = 150}),
})

-- ---- toss (frames 124-129, R29): an underhand throw for cornhole and the grill flip. The near arm swings back, forward and up ----
add("toss", {
  {lean = -1, crouch = 1, aN = -35, aNr = 10, aF = 10, aFr = 20, dur = 140},
  {lean = -2, crouch = 2, aN = -62, aNr = 6, aF = 14, aFr = 22, hrot = -3, dur = 200},
  {lean = 1, crouch = 1, aN = 25, aNr = 0, aF = 12, aFr = 20, dur = 70},
  {lean = 2, aN = 80, aNr = -4, aF = 12, aFr = 20, dur = 120},
  {lean = 2, aN = 104, aNr = -8, aF = 12, aFr = 20, dur = 220},
  {lean = 1, aN = 45, aNr = 10, aF = 10, aFr = 20, dur = 140},
})

-- ---- sitcouch (frames 130-135, R26): on a couch the far arm goes up and back and lies along the top of the backrest, the near hand rests ----
add("sitcouch", {
  seat({keepN = false, keepF = false, aN = 10, aNr = 30, aF = 20, aFr = 40, lean = -1, dur = 160}),
  seat({keepN = false, keepF = false, aN = 14, aNr = 34, aF = -50, aFr = 12, lean = -2, hrot = -2, dur = 160}),
  seat({keepN = false, keepF = false, aN = 15, aNr = 35, aF = -96, aFr = 22, lean = -3, hrot = -4, dur = 420}),
  seat({keepN = false, keepF = false, aN = 16, aNr = 36, aF = -100, aFr = 26, lean = -3, hrot = -8, hy = -1, dur = 620}),
  seat({keepN = false, keepF = false, aN = 15, aNr = 35, aF = -98, aFr = 24, lean = -3, hrot = -7, hy = -1, face = "blink", dur = 140}),
  seat({keepN = false, keepF = false, aN = 12, aNr = 32, aF = -40, aFr = 14, lean = -1, dur = 160}),
})

return poses, tags
