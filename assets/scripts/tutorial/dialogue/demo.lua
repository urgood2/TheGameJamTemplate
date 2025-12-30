local TutorialDialogue = require("tutorial.dialogue")

local TutorialDialogueDemo = {}

function TutorialDialogueDemo.runBasicDemo()
    local dialogue = TutorialDialogue.new({
        speaker = {
            sprite = "sample_pack.png",
            position = "left",
            size = { 96, 96 },
            shaders = { "efficient_pixel_outline" },
            jiggle = { enabled = true, intensity = 0.1, speed = 10 },
            idleFloat = { enabled = true, amplitude = 5, speed = 1.2 },
        },
        box = {
            position = "bottom",
            width = 600,
            style = "default",
            padding = 20,
            nameplate = true,
        },
        text = {
            fontSize = 18,
            typingSpeed = 0.04,
        },
        spotlight = {
            enabled = true,
            size = 0.35,
            feather = 0.15,
        },
        input = {
            prompt = "Press [SPACE] to continue",
            key = "space",
        },
    })
    
    dialogue
        :say("Welcome, adventurer!", { speaker = "Guide" })
        :say("I will teach you the basics of this world.")
        :say("Pay close attention to what I'm about to show you.")
        :waitForInput("space")
        :say("Let's begin with movement controls.")
        :say("Use WASD keys to move around the map.")
        :call(function()
            print("[Tutorial] Movement section complete")
        end)
        :say("Excellent! You're a quick learner.")
        :onComplete(function()
            print("[Tutorial] Demo complete!")
        end)
        :start()
    
    return dialogue
end

function TutorialDialogueDemo.runMultiSpeakerDemo()
    local dialogue = TutorialDialogue.new({
        speaker = {
            sprite = "sample_pack.png",
            position = "left",
            size = { 80, 80 },
        },
        box = {
            position = "bottom",
            width = 550,
            style = "magical",
        },
        spotlight = { enabled = false },
    })
    
    dialogue
        :say("Greetings, traveler.", { speaker = "Elder Sage" })
        :say("The prophecy spoke of your arrival.")
        :setSpeaker({
            sprite = "sample_card.png",
            position = "right",
            size = { 80, 80 },
            shaders = { "3d_skew_holo" },
        })
        :say("What prophecy? I just got here!", { speaker = "Hero" })
        :setSpeaker({
            sprite = "sample_pack.png",
            position = "left",
            size = { 80, 80 },
        })
        :say("All in due time, young one.", { speaker = "Elder Sage" })
        :say("First, you must prove yourself worthy.")
        :onComplete(function()
            print("[Tutorial] Multi-speaker demo complete!")
        end)
        :start()
    
    return dialogue
end

function TutorialDialogueDemo.runSpotlightDemo()
    local screenW = (globals and globals.screenWidth and globals.screenWidth()) or 1920
    local screenH = (globals and globals.screenHeight and globals.screenHeight()) or 1080
    
    local dialogue = TutorialDialogue.new({
        speaker = {
            sprite = "sample_pack.png",
            position = "bottom_left",
            size = { 64, 64 },
        },
        box = {
            position = "bottom",
            width = 500,
            style = "dark",
        },
        spotlight = {
            enabled = true,
            size = 0.25,
            feather = 0.1,
        },
    })
    
    dialogue
        :say("Let me highlight some important areas.", { speaker = "Guide" })
        :focusOn({ x = 0.2, y = 0.3 }, 0.15)
        :say("This is the inventory area.")
        :focusOn({ x = 0.8, y = 0.3 }, 0.15)
        :say("And this is your minimap.")
        :focusOn({ x = 0.5, y = 0.5 }, 0.3)
        :say("The center of the screen is your main view.")
        :unfocus()
        :say("That concludes the UI overview!")
        :onComplete(function()
            print("[Tutorial] Spotlight demo complete!")
        end)
        :start()
    
    return dialogue
end

function TutorialDialogueDemo.runQuickMessage(text, opts)
    return TutorialDialogue.quick(text, opts)
end

function TutorialDialogueDemo.runStyleShowcase()
    local styles = { "default", "dark", "light", "magical" }
    local currentIndex = 1
    
    local function showNextStyle()
        if currentIndex > #styles then
            print("[Tutorial] Style showcase complete!")
            return
        end
        
        local style = styles[currentIndex]
        local dialogue = TutorialDialogue.new({
            speaker = {
                sprite = "sample_pack.png",
                position = "center",
                size = { 64, 64 },
            },
            box = {
                position = "center",
                width = 400,
                style = style,
            },
            spotlight = { enabled = false },
        })
        
        dialogue
            :say("This is the '" .. style .. "' style.", { speaker = "Demo" })
            :say("Notice the colors and appearance.")
            :onComplete(function()
                currentIndex = currentIndex + 1
                timer.after(0.5, showNextStyle)
            end)
            :start()
    end
    
    showNextStyle()
end

return TutorialDialogueDemo
