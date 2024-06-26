globals [
  lane-width     ;; Width of each lane
  car-length     ;; Length of each car
  max-velocity   ;; Maximum velocity of cars
  max-displacement ;; Maximum displacement for staggering starting positions
  lanes
  number-of-lanes
  actions-merge
  actions-continue
  redx
  acceleration
]

turtles-own [
  speed         ; the current speed of the car
  top-speed     ; the maximum speed of the car (different for all cars)
  target-lane   ; the desired lane of the car
  action        ; the driver's action (LCA or LCB; C or Y)
]

to setup
  clear-all
  set number-of-lanes 2
  set-default-shape turtles "car"

  draw-road
  ;; Set up simulation parameters
  set lane-width 4
  set car-length 4.6
  set max-velocity 12
  set max-displacement 6.9
  set redx 12
  set acceleration 0.01

  ; C or Y
   create-turtles 1 [
    set color orange
    setxy 4 + orange-displacement -1
    set size 2
    set target-lane pycor
    set heading 90
    set top-speed max-velocity
    ifelse orange-yield [
      ; Set speed to a low random interval if LCB
      set speed random-float (max-velocity * 0.125) + (max-velocity * 0.125)
    ] [
      ; Set speed to a high random interval if LCA
      set speed random-float (max-velocity * 0.75) + (max-velocity * 0.25)
    ]
  ]

  ; LCA or LCB
  create-turtles 1 [
    set color violet
    setxy 4 + violet-displacement 1
    set size 2
    set target-lane -1
    set heading 90
    set top-speed max-velocity
    ifelse violet-merge-behind [
      ; Set speed to a low random interval if LCB
      set speed random-float (max-velocity * 0.125) + (max-velocity * 0.125)
    ] [
      ; Set speed to a high random interval if LCA
      set speed random-float (max-velocity * 0.75) + (max-velocity * 0.25)
    ]
  ]

  create-turtles 1 [
    set color red
    setxy redx 1
    set size 2
    set target-lane 1
    set heading 90
    set top-speed 0
    set speed 0
  ]

  reset-ticks
end

to draw-road
  ask patches [
    ; the road is surrounded by green grass of varying shades
    set pcolor green - random-float 0.5
  ]
  set lanes n-values number-of-lanes [ n -> number-of-lanes - (n * 2) - 1 ]
  ask patches with [ abs pycor <= number-of-lanes ] [
    ; the road itself is varying shades of grey
    set pcolor grey - 2.5 + random-float 0.25
  ]
  draw-road-lines
end

to draw-road-lines
  let y (last lanes) - 1 ; start below the "lowest" lane
  while [ y <= first lanes + 1 ] [
    if not member? y lanes [
      ; draw lines on road patches that are not part of a lane
      ifelse abs y = number-of-lanes
        [ draw-line y yellow 0 ]  ; yellow for the sides of the road
        [ draw-line y white 0.5 ] ; dashed white between lanes
    ]
    set y y + 1 ; move up one patch
  ]
end

to draw-line [ y line-color gap ]
  ; We use a temporary turtle to draw the line:
  ; - with a gap of zero, we get a continuous line;
  ; - with a gap greater than zero, we get a dashed line.
  create-turtles 1 [
    setxy (min-pxcor - 0.5) y
    hide-turtle
    set color line-color
    set heading 90
    repeat world-width [
      pen-up
      forward gap
      pen-down
      forward (1 - gap)
    ]
    die
  ]
end


to go
  if is-finished? or has-passed-red-car? [stop]
  ask turtles [ move-forward ]
  ;move-cars
  ;check-collisio
  ask turtles with [ ycor != target-lane ] [ move-to-target-lane ]
  ask turtles with [color = violet][]
  if spectator-mode [wait 0.001]
  tick
end

to move-forward ; turtle procedure
  set heading 90
  speed-up-car ; we tentatively speed up, but might have to slow down
  let blocking-cars other turtles in-cone 2 180 with [ y-distance <= 1 ]
  let blocking-car min-one-of blocking-cars [ distance myself ]
  if blocking-car != nobody [
    ; match the speed of the car ahead of you and then slow
    ; down so you are driving a bit slower than that car.
    set speed [ speed ] of blocking-car
    slow-down-car
  ]
  forward speed / 1000
end

to-report x-distance
  report distancexy [ xcor ] of myself ycor
end

to-report y-distance
  report distancexy xcor [ ycor ] of myself
end

to slow-down-car ;
  set speed (speed - 0.1 * speed)
  if speed < 0 [ set speed 0 ]
end

to speed-up-car ; turtle procedure
  set speed (speed + acceleration)
  if speed > top-speed [ set speed top-speed ]
  if speed < 0 [ set speed 0 ]
end

to move-to-target-lane
  set heading ifelse-value target-lane < ycor [ 180 ] [ 0 ]
  while [ycor != target-lane] [
    let blocking-cars cars-in-oval
    if any? blocking-cars [
      ; Stop moving if there is a car in the oval window
      stop
    ]
    ; Move in smaller increments towards the target lane
    forward 1
    set ycor precision ycor 1 ; to avoid floating point errors
  ]
end

to-report cars-in-oval
  ; Oval window dimensions
  let x-range 3
  let y-range 2
  report other turtles with [
    abs (xcor - [xcor] of myself) <= x-range and
    abs (ycor - [ycor] of myself) <= y-range
  ]
end

to-report is-crashed?
  let violet-car one-of turtles with [color = violet]
  let red-car one-of turtles with [color = red]
  if violet-car != nobody and red-car != nobody [
    if [xcor] of violet-car + 2 > [xcor] of red-car and [ycor] of violet-car = [ycor] of red-car [
      report true
    ]
  ]
  report false
end

to-report has-passed-red-car?
  let violet-car one-of turtles with [color = violet]
  let red-car one-of turtles with [color = red]
  if violet-car != nobody and red-car != nobody [
    if [xcor] of violet-car > [xcor] of red-car [
      report true
    ]
  ]
  report false
end

to-report is-finished?
  report ticks > 10000 or is-crashed?
end

to-report total-time
  if ticks > 10000 [ report 10000 ]
  if is-finished? [report 10000]
  if has-passed-red-car? [ report ticks ]
  report ticks ;; Default to current ticks if none of the above conditions are met
end

to-report violet-speed
  let violet-car one-of turtles with [color = violet]
  if violet-car != nobody[
    report [speed] of violet-car
    ]
  report -1
end

to-report orange-speed
  let orange-car one-of turtles with [color = orange]
  if orange-car != nobody[
    report [speed] of orange-car
    ]
  report -1
end

@#$#@#$#@
GRAPHICS-WINDOW
217
23
540
287
-1
-1
15.0
1
10
1
1
1
0
0
0
1
0
20
-8
8
0
0
1
ticks
30.0

BUTTON
9
34
73
67
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
102
35
165
68
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
8
97
208
130
violet-merge-behind
violet-merge-behind
0
1
-1000

SWITCH
10
152
135
185
orange-yield
orange-yield
0
1
-1000

PLOT
570
46
770
196
Car Speed
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"violet speed" 1.0 0 -10141563 true "" "plot violet-speed"
"orange speed" 1.0 0 -817084 true "" "plot orange-speed"

PLOT
569
217
769
367
Total Time
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"time" 1.0 0 -13840069 true "" "plot total-time"

SWITCH
10
205
182
238
spectator-mode
spectator-mode
1
1
-1000

SLIDER
10
251
190
284
orange-displacement
orange-displacement
0
3
1.0
0.5
1
NIL
HORIZONTAL

SLIDER
12
298
193
331
violet-displacement
violet-displacement
0
3
1.5
0.5
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This model investigates under what conditions conflict arises in a specific interaction between cars. The situation is one car having to merge into a neighbouring lane because there is an obstacle in the way, while there already is a car driving in the target lane.

## HOW IT WORKS

The agents (cars) each choose an action: Either they try to go fast, and be the first car, called Lane Change Ahead (LCA) for violet and Current Speed (C) for orange, or they try to drive slowly and let the other car be first, called Lane Change Behind (LCB) for violet or Yield (Y) for orange. In this implementation you can choose the action they should take through the violet-merge-behind and the orange-yield switches to the left.

Depeding on the actions chosen using the switches, the cars will be assigned a random starting speed. If they choose the faster action, their speed will be faster. Then they slowly accelerate to a macimal speed. If the violet car notices that the target lane is free and thus switching lanes is possible, it will do so. If it is not possible to switch lanes in time, violet will run into the red car in front and the simulation will return the maximum time of 10000 ticks to indicate conflict. The system will also report this maximal time if the orange car does not pass the red car in 10000 ticks. If the orange car does manage to complete the lane change and pass the red car in 10000 ticks, then the ticks it took for that are reported.

## HOW TO USE IT

Setup: Draws the environment and chooses the random speeds based on the actions
Go: Starts one run
violet-merge-behind: choose the actions for the violet car, LCB if true and LCA if false
orange-yield: choose the actions for the orange car, Y if true and C if false
spectator-mode: adds a delay to each ticks to better visualize the simulation if true
displacement: these sliders control the intial displacements of the orange and violet car

To carry out the repeated runs for the experiments and analysis you can click on Tools -> BehaviorSpace where you can see the experiments we ran or create your own.

## THINGS TO TRY

Try varying the actions and the displacements!

## THINGS TO NOTICE

Notice how it is a lot more likely for conflict to happen if the cars both choose the aggressive or the passive actions.

Also notice how when varying the displacements, conflicts is more likely the closer the cars are at the beginning.


## EXTENDING THE MODEL

One can implement a more difficult model for deciding the speeds. One such model is detailed in the paper "Resolving Conflict in Decision-Making for
Autonomous Driving" by Jack Geary et. al.


## CREDITS AND REFERENCES

Resolving Conflict in Decision-Making for Autonomous Driving by Jack Geary et.al.
This model was adapted from the NetLogo example model: https://ccl.northwestern.edu/netlogo/models/Traffic2Lanes
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Y, LCA" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-time</metric>
    <runMetricsCondition>is-finished? or has-passed-red-car?</runMetricsCondition>
    <enumeratedValueSet variable="orange-yield">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="violet-merge-behind">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Y, LCB" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-time</metric>
    <runMetricsCondition>is-finished? or has-passed-red-car?</runMetricsCondition>
    <enumeratedValueSet variable="orange-yield">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="violet-merge-behind">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="C, LCB" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-time</metric>
    <runMetricsCondition>is-finished? or has-passed-red-car?</runMetricsCondition>
    <enumeratedValueSet variable="orange-yield">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="violet-merge-behind">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="C, LCA" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-time</metric>
    <runMetricsCondition>is-finished? or has-passed-red-car?</runMetricsCondition>
    <enumeratedValueSet variable="orange-yield">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="violet-merge-behind">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="C, LCA displacement" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-time</metric>
    <runMetricsCondition>is-finished? or has-passed-red-car?</runMetricsCondition>
    <enumeratedValueSet variable="orange-yield">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="violet-merge-behind">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="spectator-mode">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="violet-displacement">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="1.5"/>
      <value value="2"/>
      <value value="2.5"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="orange-displacement">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="1.5"/>
      <value value="2"/>
      <value value="2.5"/>
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Y, LCA displacement" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-time</metric>
    <runMetricsCondition>is-finished? or has-passed-red-car?</runMetricsCondition>
    <enumeratedValueSet variable="orange-yield">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="violet-merge-behind">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="spectator-mode">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="violet-displacement">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="1.5"/>
      <value value="2"/>
      <value value="2.5"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="orange-displacement">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="1.5"/>
      <value value="2"/>
      <value value="2.5"/>
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Y, LCB displacement" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-time</metric>
    <runMetricsCondition>is-finished? or has-passed-red-car?</runMetricsCondition>
    <enumeratedValueSet variable="orange-yield">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="violet-merge-behind">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="spectator-mode">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="violet-displacement">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="1.5"/>
      <value value="2"/>
      <value value="2.5"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="orange-displacement">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="1.5"/>
      <value value="2"/>
      <value value="2.5"/>
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="C, LCB displacement" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-time</metric>
    <runMetricsCondition>is-finished? or has-passed-red-car?</runMetricsCondition>
    <enumeratedValueSet variable="orange-yield">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="violet-merge-behind">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="spectator-mode">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="violet-displacement">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="1.5"/>
      <value value="2"/>
      <value value="2.5"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="orange-displacement">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="1.5"/>
      <value value="2"/>
      <value value="2.5"/>
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
