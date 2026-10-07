local activePromotions = {}

GetActivePromotions = function()
    return activePromotions
end

GetPromotionFor = function(dealerId, model)
    for _, promo in ipairs(activePromotions) do
        if promo.dealer == dealerId and promo.model == model then
            return promo
        end
    end
    return nil
end

ApplyPromotion = function(dealerId, model, price)
    local promo = GetPromotionFor(dealerId, model)
    if not promo then return price, nil end
    return math.floor(price * (100 - promo.discount) / 100), promo
end

EligiblePromoIndexes = function(category)
    local out = {}
    for i, car in ipairs(category.cars or {}) do
        if not car.noPromo then
            out[#out + 1] = i
        end
    end
    return out
end

PickPromoCategory = function(dealer)
    local categories = dealer.categories or {}
    if #categories == 0 then return nil end
    if KOJA.Promotions.category ~= 'random' then
        for _, category in ipairs(categories) do
            if category.name == KOJA.Promotions.category and #EligiblePromoIndexes(category) > 0 then
                return category
            end
        end
        return nil
    end
    local valid = {}
    for _, category in ipairs(categories) do
        if #EligiblePromoIndexes(category) > 0 then
            valid[#valid + 1] = category
        end
    end
    if #valid == 0 then return nil end
    return valid[math.random(#valid)]
end

RollPromotions = function()
    activePromotions = {}
    if not KOJA.Promotions.enable then return end
    local endsAt = os.time() + (KOJA.Promotions.interval * 60)
    for _, dealer in ipairs(Dealers) do
        local category = PickPromoCategory(dealer)
        if category then
            local cars = category.cars
            local indexes = EligiblePromoIndexes(category)
            if #indexes > 0 then
            local count = math.random(KOJA.Promotions.count.min, KOJA.Promotions.count.max)
            count = math.min(count, #indexes)
            for i = #indexes, 2, -1 do
                local j = math.random(i)
                indexes[i], indexes[j] = indexes[j], indexes[i]
            end
            for i = 1, count do
                local car = cars[indexes[i]]
                activePromotions[#activePromotions + 1] = {
                    dealer = dealer.id,
                    category = category.name,
                    model = car.model,
                    discount = math.random(KOJA.Promotions.discount.min, KOJA.Promotions.discount.max),
                    endsAt = endsAt
                }
            end
            end
        end
    end
    print(('[KOJA_CARDEALER] Rolled %s promotion(s)'):format(#activePromotions))
end

CreateThread(function()
    Wait(2000)
    RollPromotions()
    SyncDealers()
    while true do
        Wait(KOJA.Promotions.interval * 60 * 1000)
        RollPromotions()
        SyncDealers()
    end
end)
