The hitfx mixin is used to make objects flash and go boing whenever they're hit by something. It's a conjunction of springs and flashes into one because they're often used together. If you want an explanation of how the springs work I wrote this post before which goes over it in great detail.

The way to create a new hitfx effect is simply to call hitfx_add:

self:hitfx_add('hit', 1)

And this would add a spring + flash named 'hit' to the object. This spring's default value would be 1, which is a useful value when you want to attach it to an object's scale, for instance, since when you pull on the spring it will bounce around that 1 value, which is what you want to make an object go boing:

self:hitfx_use('hit', 0.5)

And so this would make the springs initial value 1.5, and it would slowly converge to 1 while bouncing around in a spring-like fashion. To use the spring's value you would simply access self.springs.hit.x and then do whatever you'd want with it. This is one of the advantages of having everything as mixins. Because the mixin is in the object itself, accessing any mixin state is as easy as accessing any other variable, a zero bureaucracy setup. In code, you'll often find me using these like this:

game2:push(self.drop_x, self.drop_y, 0, self.springs.drop.x, self.springs.drop.x)
  game2:draw_image_or_quad(self.emoji, self.x + self.shake_amount.x, self.y + self.shake_amount.y, self.r, 
    self.sx*self.springs.main.x, self.sy*self.springs.main.x, 0, 0, colors.white[0], 
    (self.dying and shaders.grayscale) or (self.flashes.main.x and shaders.combine))
game2:pop()

This example is a bit involved, but given how common it is and how it has the use of multiple mixins, multiple springs and flashes, it's worth going over it. First, this is the part where an emoji in emoji merge gets drawn. The push/pop pair is making it so that the 'drop' spring scales the emoji around the .drop_x, .drop_y position, which is a position that is the exact middle between the emoji that is about to be dropped and the little hand that drops it. Scaling things around their center vs. scaling things around a common shared position looks different, and in this case I wanted to scale both the hand and the emoji around their common center, so that's how to do it.

Then, the emoji itself gets drawn using draw_image_or_quad. Its x, y position is offset by .shake_amount, which is a vector that contains the results from the shake mixin. This is another example of a mixin's result simply being available by accessing a variable on the object itself. Then the emoji's scale is multiplied by self.springs.main.x, which is the 'main' spring that every hitfx mixin enabled object has, and then finally the image is drawn with a shader active based on two conditions. If self.dying is true, then it uses the grayscale shader to be drawn in black and white, while if self.flashes.main.x is true, it gets drawn with the combine shader, which allows the color passed in (in this case colors.white[0]) to affect the emoji's color and make it white. self.flashes.main.x is true for a given duration based on its hitfx_use call, which for the emoji happens when its created anew from two other emojis being merged:

if self.hitfx_on_spawn then self:hitfx_use('main', 0.5*self.hitfx_on_spawn, nil, nil, 0.15) end
if self.hitfx_on_spawn_no_flash then self:hitfx_use('main', 0.5*self.hitfx_on_spawn_no_flash) end

This is on the emoji's constructor. The first hitfx_use calls the 'main' spring and has it move around by 0.5 (1.5 starting value until settles back on 1), with a flash duration of 0.15 seconds. While the second hitfx_use simply moves it by 0.5 with no flash.

And that's about it. This is a fairly useful construct that I use a lot. There are probably better ways of doing it but this works well enough for me.