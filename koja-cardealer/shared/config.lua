KOJA = {}

-- Images path for vehicles
-- Default uses the public FiveM CDN with pictures of every base GTA vehicle.
-- If an image is missing, the UI falls back to web/images/${model}.png (put custom car renders there).
-- Examples:
-- Local path: "nui://koja-cardealer/web/images/${model}.png"
-- External URL: "https://docs.fivem.net/vehicles/${model}.webp"
KOJA.ImagesPath = "https://docs.fivem.net/vehicles/${model}.webp"

-- Language for notifications, UI, etc.
-- "en", "pl"
KOJA.Locale = 'en'

-- Notifications systems
-- "esx", "qb", "ox"
KOJA.Notify = "esx"

-- Target system
-- true/false
-- If enabled, it applies a target to the car dealership ped (only for dealers with interaction = "npc")
KOJA.Target = false

KOJA.PlateFormat = {
    Letters = 4, -- Number of letters in the license plate
    Numbers = 4, -- Number of digits in the license plate
    Separator = "" -- Separator between characters on the license plate
}

-- Automatically create the required database tables on resource start.
-- Set to false if you imported koja-cardealer.sql manually.
KOJA.CreateAutoTable = false

-- Admin menu access
KOJA.Admin = {
    command = 'cardealer', -- Command that opens the admin menu
    aceResource = 'command.cardealer', -- Ace permission checked on the server (add_ace group.admin command.cardealer allow)
    groups = { 'admin', 'superadmin', '_dev' } -- Framework groups that can use the admin menu
}

-- Prestige system (optional)
-- Player prestige/xp is resolved through Misc.Utils.GetPlayerPrestige (see shared/utils.lua)
-- so you can hook it into any prestige/level resource you use.
-- The built-in prestige system stores prestige/xp in the database and levels the
-- player up automatically once xp reaches `xpPerLevel`. Manage it with the console
-- commands below or the exports:
--   exports['koja-cardealer']:AddPrestigeXP(source, amount)
--   exports['koja-cardealer']:SetPrestigeXP(source, amount)
--   exports['koja-cardealer']:AddPrestige(source, amount)
--   exports['koja-cardealer']:SetPrestige(source, amount)
--   exports['koja-cardealer']:GetPrestige(source) -> prestige, xp
KOJA.Prestige = {
    enable = true, -- If disabled, prestige requirements on vehicles are ignored
    xpPerLevel = 10000, -- XP needed for the next prestige level (used by the default progress bar)
    xpPerPurchase = 2000, -- XP granted to the player on each vehicle purchase (0 = disabled)
    commands = { -- Console (source 0) / admin commands: <command> <playerId> <amount>
        addXp = 'addxp',
        setXp = 'setxp',
        addPrestige = 'addprestige',
        setPrestige = 'setprestige'
    }
}

-- Vehicle promotions system
-- Every `interval` minutes the server rolls a promotion:
-- it picks a category (random one or a fixed one) and puts `count.min`..`count.max`
-- random vehicles from that category on sale with a random discount.
KOJA.Promotions = {
    enable = true,
    interval = 60, -- Minutes between promotion rotations
    category = 'random', -- 'random' or a fixed category name, e.g. 'Sports'
    count = { min = 2, max = 3 }, -- How many vehicles from the category get promoted
    discount = { min = 10, max = 30 } -- Discount range in percent
}

-- Limited stock system
-- Vehicles marked as `limited` in the admin menu have a stock counter.
-- The counter is decreased on purchase and persisted in data/dealers.json.
KOJA.LimitedStock = {
    enable = true,
    hideWhenSoldOut = false -- true = hide sold out vehicles, false = show them greyed out
}

-- Coupon codes
-- Players redeem a code in the dealer UI (below the color palette); the discount
-- applies to the next vehicle purchase (stacks with promotions).
-- Codes are created and managed in the ADMIN MENU (button "Kody rabatowe") and
-- stored in the database. The `codes` below are only SEED defaults inserted on the
-- very first start (when the coupon table is still empty).
--   discount      = percent off
--   maxUses       = total redemptions allowed (0 = unlimited)
--   oncePerPlayer = true => each player can use the code only once
KOJA.Coupons = {
    enable = true,
    codes = {
        -- ['KOJA10'] = { discount = 10, maxUses = 100, oncePerPlayer = true },
        -- ['LAUNCH25'] = { discount = 25, maxUses = 50, oncePerPlayer = true },
    }
}

-- VIP system
-- VIP players get access to dealers marked "Tylko VIP" in the admin menu
-- and better prices in every dealer.
-- If `purchasable` is false the buy button is hidden and VIP can only be
-- managed through exports:
--   exports['koja-cardealer']:SetPlayerVip(source, days)  -- days = 0 => lifetime
--   exports['koja-cardealer']:RemovePlayerVip(source)
--   exports['koja-cardealer']:IsPlayerVip(source)
KOJA.Vip = {
    enable = true,
    purchasable = true, -- false = VIP only via exports
    price = 500000, -- Price of the VIP purchase in the dealer UI
    days = 30, -- VIP duration in days (0 = lifetime)
    discount = 10, -- Percent better prices for VIP players in every dealer
    -- Benefits displayed in the VIP purchase modal (fully editable)
    benefits = {
        "Access to premium showrooms (VIP only)",
        "Better prices in every showroom",
        "Exclusive, limited vehicles"
    }
}

-- Leasing (vehicle financing)
-- The player pays a down payment, then recurring installments.
-- Payments are made manually in the "Financed Vehicles" panel (command below).
-- If a payment is overdue for longer than `graceHours`, a missed payment is
-- counted; after `maxMissedPayments` the vehicle is repossessed (removed).
KOJA.Leasing = {
    enable = true,
    command = 'leasing', -- Command that opens the financed vehicles panel
    downPaymentPercent = 20, -- Percent of the price paid upfront
    installments = 12, -- Number of recurring payments
    interestPercent = 10, -- Interest added to the financed amount
    paymentIntervalHours = 12, -- Real-time hours between payments
    graceHours = 12, -- Extra hours before a payment counts as missed
    maxMissedPayments = 2 -- Missed payments before the vehicle is repossessed
}

-- Test drive settings shared by every dealer
KOJA.TestDrive = {
    secondslimit = 30, -- Time limit in seconds for the test drive
    tuningPrice = 100, -- Price of the "Full Tuning" test drive (regular one is free)
    cancelKey = 73 -- Key to cancel the test drive (default: X)
}

-- Default spawn points used by dealers created from the admin menu.
-- The preview spawn should be a place the player can never see (e.g. under the map).
KOJA.Defaults = {
    vehicleSpawn = {
        coords = vector3(59.5326, -2213.4165, -0.1504 - 0.99), -- Preview vehicle spawn (hidden area)
        heading = 162.0
    },
    ped = {
        pedHash = 0x2930C1AB, -- Ped model used for "npc" interaction dealers
        drawText = "[E] - Open Car Dealer",
        drawTextTarget = 'Open Car Dealer',
        drawDistance = 20
    },
    blip = {
        sprite = 225,
        colour = 26,
        scale = 0.8,
        visible = true
    }
}
