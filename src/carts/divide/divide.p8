pico-8 cartridge // http://www.pico-8.com
version 39
__lua__

-- TODO: use pico8 buildtools:
-- https://github.com/dansanderson/picotool

local class = {}

-- Baseclass of all objects.
class.Object = {}
class.Object.class = class.Object
--- Nullary constructor.
function class.Object:init (...)
end
--- Base alloc method.
function class.Object.alloc (mastertable)
	return setmetatable({}, {__index = class.Object, __newindex = mastertable})
end
--- Base new method.
function class.Object.new (...)
	return class.Object.alloc({}):init(...)
end
--- Checks if this object is an instance of class.
-- @param class The class object to check.
-- @return Returns true if this object is an instance of class, false otherwise.
function class.Object:instanceOf (class)
	-- Recurse up the supertypes until class is found, or until the supertype is not part of the inheritance tree.
	if self.class == class then
		return true
	end
	if self.super then
		return self.super:instanceOf(class)
	end
	return false
end

--- Creates a new class.
-- @param baseclass The Baseclass of this class, or nil.
-- @return A new class reference.
function class.class (baseclass)
	-- Create the class definition and metatable.
	local classdef = {}
	-- Find the super class, either Object or user-defined.
	baseclass = baseclass or class.Object
	-- If this class definition does not know of a function, it will 'look up' to the Baseclass via the __index of the metatable.
	setmetatable(classdef, {__index = baseclass})
	-- All class instances have a reference to the class object.
	classdef.class = classdef
	--- Recursivly allocates the inheritance tree of the instance.
	-- @param mastertable The 'root' of the inheritance tree.
	-- @return Returns the instance with the allocated inheritance tree.
	function classdef.alloc (mastertable)
		-- All class instances have a reference to a superclass object.
		local instance = {super = baseclass.alloc(mastertable)}
		-- Any functions this instance does not know of will 'look up' to the superclass definition.
		setmetatable(instance, {__index = classdef, __newindex = mastertable})
		return instance
	end
	--- Constructs a new instance from this class definition.
	-- @param arg Arguments to this class' constructor
	-- @return Returns a new instance of this class.
	function classdef.new (...)
		-- Create the empty object.
		local instance = {}
		-- Start the process of creating the inheritance tree.
		instance.super = baseclass.alloc(instance)
		setmetatable(instance, {__index = classdef})
		-- Finally, init the object, it is up to the programmer to choose to call the super init method.
		instance:init(...)
		return instance
	end
	-- Finally, return the class we created.
	return classdef
end

--------------------------------------------------------------------------------
-- Field
--------------------------------------------------------------------------------
local Field = class.class()

function Field:init(field_color)
    self.x_min = -1
    self.x_max = 128
    self.y_min = -1
    self.y_max = 128
    self.field_color = field_color
end

function Field:set_x(x)
    if x < self.x_min or x > self.x_max then
        return
    end

    if x - self.x_min < self.x_max - x then
        self.x_min = x
    else
        self.x_max = x
    end
end

function Field:set_y(y)
    if y < self.y_min or y > self.y_max then
        return
    end

    if y - self.y_min < self.y_max - y then
        self.y_min = y
    else
        self.y_max = y
    end
end

function Field:update()
end

function Field:draw()
    rectfill(-1, -1, self.x_min, 128, self.field_color)
    rectfill(self.x_max, -1, 128, 128, self.field_color)
    rectfill(-1, -1, 128, self.y_min, self.field_color)
    rectfill(-1, self.y_max, 128, 128, self.field_color)
end

--------------------------------------------------------------------------------
-- Player
--------------------------------------------------------------------------------
local Player = class.class()

function Player:init(field, lives, beam_color)
    self.lives = lives
    self.max_lives = lives+2
    self.score = 0

    self.x = 0
    self.y = 0
    self.l_long = 3
    self.l_short = 2
    self.speed = 1
    self.dir_lr = false
    self.fire = false
    self.fire_len = 0

    self.field = field
    self.beam_color = beam_color
end

function Player:update()
    self:update_buttons()
    self:update_beam()
end

function Player:update_buttons()
    if self.fire then
        return
    end

    -- left, right, up, down
	if btn(0) then 
		self.x -= self.speed
        self.dir_lr = true
	elseif btn(1) then
		self.x += self.speed
        self.dir_lr = true
    end
    if btn(2) then
        self.y -= self.speed
        self.dir_lr = false
	elseif btn(3) then
        self.y += self.speed
        self.dir_lr = false
    end
    if btnp(❎) then
        if self.x > field.x_min and self.x < field.x_max and
           self.y > field.y_min and self.y < field.y_max then
            self.fire = true
        end
    end
    if btnp(🅾️) then
        self.dir_lr = not self.dir_lr
    end
end

function Player:draw()
    w = self.l_long
    h = self.l_short
    if self.dir_lr then
        w = self.l_short
        h = self.l_long
    end
    -- TODO: nice graphics
    rectfill(self.x-w, self.y-h, self.x + w, self.y+h, 9)

    if self.fire then
        self:draw_beam()
    end

    -- Draw HUD
    print("score: " .. self.score, 5, 5, 6)
    for i = 0, self.max_lives - 1 do
        -- draw from right to left => invert colors
        color = 8 -- red
        if i < self.max_lives - self.lives then
            color = 6 -- gray
        end
        print("♥", 117-i*6, 5, color)
    end
end

function Player:check_collision(enemies)
end

function Player:update_beam()
    if not self.fire then
        return
    end

    -- get min/max of the fire beam
    if self.dir_lr == false then
        smaller = self.x - self.l_long - self.fire_len
        larger = self.x + self.l_long + self.fire_len
        min = self.field.x_min
        max = self.field.x_max
    else
        smaller = self.y - self.l_long - self.fire_len
        larger = self.y + self.l_long + self.fire_len
        min = self.field.y_min
        max = self.field.y_max
    end

    -- check fire success
    if smaller <= min and larger >= max then
        self.fire = false
        self.fire_len = 0

        if self.dir_lr then
            field:set_x(self.x)
        else
            field:set_y(self.y)
        end
    end
end

function Player:draw_beam()
    self.fire_len += 1

    if self.dir_lr == false then
        x_left = self.x - self.l_long
        x_right = self.x + self.l_long

        for i = 0,self.fire_len do
            x_left -= 1
            x_right += 1
            y = (i % 2 == 0) and self.y or self.y+1

            if x_left > field.x_min then circ(x_left, y, 0, self.beam_color) end
            if x_right < field.x_max then circ(x_right, y, 0, self.beam_color) end
        end
    else
        y_up = self.y - self.l_long
        y_down = self.y + self.l_long

        for i = 0,self.fire_len do
            y_up -= 1
            y_down += 1
            x = (i % 2 == 0) and self.x or self.x+1

            if y_up > field.y_min then circ(x, y_up, 0, self.beam_color) end
            if y_down < field.y_max then circ(x, y_down, 0, self.beam_color) end
        end
    end
end
--------------------------------------------------------------------------------
-- Enemy: Base
--------------------------------------------------------------------------------
local Enemy = class.class()

function Enemy:init(field, sprite, w, h)
    self.field = field
    self.sprite = sprite

    self.x = field.x_min + rnd(field.x_max - field.x_min + 1)
    self.y = field.y_min + rnd(field.y_max - field.y_min + 1)

    self.w = w
    self.h = h
end

function Enemy:update()
    -- Stub: Subclass has to implement the update behaviour
end

function Enemy:draw()
    spr(self.sprite, self.x, self.y, self.w, self.h)
end    

--------------------------------------------------------------------------------
-- Enemy: Fireball
--------------------------------------------------------------------------------
local EnemyFireball = class.class(Enemy)

function EnemyFireball:init(field, speed)
	self.super:init(field, 1, 1, 1)
    self.vel_x = speed
    self.vel_y = speed
end

function EnemyFireball:update()
    if self.x + self.vel_x < self.field.x_min or
       self.x + self.vel_x > self.field.x_max - 8 then
        self.vel_x = -self.vel_x
    end
    if self.y + self.vel_y < self.field.y_min or
       self.y + self.vel_y > self.field.y_max - 8 then
        self.vel_y = -self.vel_y
    end

    self.x += self.vel_x
    self.y += self.vel_y
end

--------------------------------------------------------------------------------
-- Level
--------------------------------------------------------------------------------
local Level = class.class()

function Level:init(field, player, level)
    self.field = field
    self.player = player

    if level == 1 then
        self:level1()
    end
end

function Level:level1()
    self.enemies = {
        EnemyFireball.new(self.field, 1)
    }
end

function Level:update()
    self.field:update()
    self.player:update()
    for enemy in all(self.enemies) do
        enemy:update()
    end

    -- TODO: Check collisions
end

function Level:draw()
    self.field:draw()
    self.player:draw()
    for enemy in all(self.enemies) do
        enemy:draw()
    end
end

-- dir: 
-- 0 ... left
-- 1 ... right
-- 2 ... up
-- 3 ... down
function _init()
    load_game()
    reset_game()

    scene = "menu"
    
end

function load_game()
    cartdata("laellar_divide_1")
	highscore = dget(1)
end

function save_game()
 if score > highscore then
 	dset(1, score)
 	highscore = score
 	new_high = true
 else
 	new_high = false
 end 
end

function _update()
	if scene == "menu" then
		update_menu()
	elseif scene == "game_over" then
		update_game_over()
	elseif scene == "game" then
		update_game()
	end
end

function _draw()
	if scene == "menu" then
		draw_menu()
	elseif scene == "game_over" then
		draw_game_over()
	else
		draw_game()
	end
end

----------------------
-- menu
----------------------
function update_menu()
 if btnp(❎) then
  reset_game()
  scene="game"
 end
end

function draw_menu()
	cls(1)
 print("highscore: " .. highscore, 40, 53, 9)
 print("press ❎ to start",30,73, 6)
end

----------------------
-- game over
----------------------
function update_game_over()
 if btnp(❎) then
  reset_game()
  scene="game"
 end
end

function draw_game_over()
	cls(1)
    print("you are dead :(", 30, 45, 8) 
    print("score: " .. score, 30, 55, 9)
    if new_high then
        print("♥ new highscore ♥", 30, 65, 9)
    else
        print("highscore: " .. highscore, 30, 65, 6)
    end
    
    print("press ❎ to restart", 30, 80, 6)
end

----------------------
-- game logic
----------------------
function reset_game()
    -- colors
    field_color = 12
    player_beam_color = 9

    -- player
    field = Field.new(field_color)
    player = Player.new(field, 3, player_beam_color)
    level = Level.new(field, player, 1)
	
	-- game state
	is_dead = false
	score = 0

end

function update_game()
	-- stop updating if dead
	if is_dead then
		return
	end
	
	level:update()
end

function food_collision()
	if flr(posx) >= foodx-cell_size and
				flr(posx) <= foodx+cell_size and
	   flr(posy) >= foody-cell_size and
	   flr(posy) <= foody+cell_size then
	   update_food()
	   add_part = true
	   score += 1
	   speed += 0.05
	   sfx(1)
	end
end

function draw_game()
	cls(1)
		
	if is_dead then
	 save_game()
	 scene = "game_over"
	else
        level:draw()
	end
end
__gfx__
00000000008888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000088888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000888888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000888888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000888888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000888888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000088888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000008888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
