The slow mixin uses the timer mixin to slow down the game by a certain percentage and slowly tween it back to normal speed. The main.slow_amount variable is multiplied by main.rate in love.run whenever it is passed to any update function, so if main.slow_amount is 0.5 then the game will run half as fast as normal.

So, whenever main:slow_slow is called it just does that for a given duration:

function slow:slow_slow(amount, duration, tween_method)
  amount = amount or 0.5
  duration = duration or 0.5
  tween_method = tween_method or math.cubic_in_out
  self.slow_amount = amount
  self:timer_tween(duration, self, {slow_amount = 1}, tween_method, function() self.slow_amount = 1 end, 'slow')
end

Here you can see a real use of timer's tagging mechanism. This slow timer call is tagged with the 'slow' tag, which means that if its called multiple times while another slow is going on, the slows won't stack. The old one will simply stop working and the new one will take over, which is the behavior you'd generally want.