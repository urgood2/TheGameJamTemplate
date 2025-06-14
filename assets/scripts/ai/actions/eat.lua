return {
    name = "eat",
    cost = 1,
    pre = { hungry = true },
    post = { hungry = false },

    start = function(self, e)
        print("Entity", e, "is eating.")
    end,

    update = function(self, e, dt)
        wait(1.0)
        return "SUCCESS"
    end,

    finish = function(self, e)
        print("Done eating.")
    end
}