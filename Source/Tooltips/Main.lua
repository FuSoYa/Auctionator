local L = Auctionator.Locales.Apply

local waitingForPricing = false
-- Auctionator.Config.Options.VENDOR_TOOLTIPS: true if should show vendor tips
-- Auctionator.Config.Options.SHIFT_STACK_TOOLTIPS: true to show stack price when [shift] is down
-- Auctionator.Config.Options.ALT_FULL_STACK_TOOLTIPS: true to show full stack price when [alt] is down
-- Auctionator.Config.Options.AUCTION_TOOLTIPS: true if should show auction tips
function Auctionator.Tooltip.ShowTipWithPricing(tooltipFrame, itemLink, itemCount)
  if waitingForPricing or Auctionator.Database == nil then
    return
  end
  -- Keep this commented out unless testing please.
  -- Auctionator.Debug.Message("Auctionator.Tooltip.ShowTipWithPricing", itemLink, itemCount)

  waitingForPricing = true
  Auctionator.Utilities.DBKeyFromLink(itemLink, function(dbKeys)
    waitingForPricing = false
    Auctionator.Tooltip.ShowTipWithPricingDBKey(tooltipFrame, dbKeys, itemLink, itemCount)
  end)
end

function Auctionator.Tooltip.ShowTipWithPricingDBKey(tooltipFrame, dbKeys, itemLink, itemCount)
  if #dbKeys == 0 or Auctionator.Utilities.IsPetDBKey(dbKeys[1]) then
    return
  end

  local showStackPrices = IsShiftKeyDown();
  local showFullStackPrices = IsAltKeyDown();
  
  if not Auctionator.Config.Get(Auctionator.Config.Options.ALT_FULL_STACK_TOOLTIPS) then
    showFullStackPrices = false
  end
  
  local itemInfo = { GetItemInfo(itemLink) };
  if showFullStackPrices then
    if (#itemInfo) ~= 0 then
      itemCount = itemInfo[Auctionator.Constants.ITEM_INFO.STACK_SIZE]
    end
  end

  if not Auctionator.Config.Get(Auctionator.Config.Options.SHIFT_STACK_TOOLTIPS) then
    showStackPrices = not IsShiftKeyDown();
  end

  local countString = ""
  if (itemCount and showStackPrices) or (itemCount and showFullStackPrices) then
    countString = Auctionator.Utilities.CreateCountString(itemCount)
  end

  local auctionPrice = Auctionator.Database:GetFirstPrice(dbKeys)
  local auctionAge, showAgeUnknown = nil, false
  if auctionPrice ~= nil then
    auctionPrice = auctionPrice * ((showStackPrices or showFullStackPrices) and itemCount or 1)
    auctionAge = Auctionator.Database:GetPriceAge(dbKeys[1])
    if auctionAge == nil and auctionPrice ~= nil then
      showAgeUnknown = Auctionator.Database:GetPrice(dbKeys[1]) ~= nil
    end
  end
  local auctionMean
  if Auctionator.Config.Get(Auctionator.Config.Options.AUCTION_MEAN_TOOLTIPS) then
    auctionMean = Auctionator.Database:GetMeanPrice(dbKeys[1], Auctionator.Config.Get(Auctionator.Config.Options.AUCTION_MEAN_DAYS_LIMIT))
  end
  if auctionMean ~= nil then
    auctionMean = auctionMean * ((showStackPrices or showFullStackPrices) and itemCount or 1)
  end

  local vendorPrice, disenchantStatus, disenchantPrice
  local cannotAuction = 0;

  if (#itemInfo) ~= 0 then
    cannotAuction = Auctionator.Utilities.IsBound(itemInfo)
    local sellPrice = itemInfo[Auctionator.Constants.ITEM_INFO.SELL_PRICE]

    if Auctionator.Utilities.IsVendorable(itemInfo) then
      vendorPrice = sellPrice * ((showStackPrices or showFullStackPrices) and itemCount or 1);
    end

    disenchantStatus = Auctionator.Enchant.DisenchantStatus(itemInfo)
    local disenchantPriceForOne = Auctionator.Enchant.GetDisenchantAuctionPrice(itemLink, itemInfo)
    if disenchantPriceForOne ~= nil then
      disenchantPrice = disenchantPriceForOne * ((showStackPrices or showFullStackPrices) and itemCount or 1)
    end
  end

  local prospectStatus = false
  local prospectValue
  if Auctionator.Prospect then
    local itemID = GetItemInfoInstant(itemLink)
    prospectStatus = Auctionator.Prospect.IsProspectable(itemID)
    local prospectForOne = Auctionator.Prospect.GetProspectAuctionPrice(itemID)
    if prospectForOne ~= nil then
      prospectValue = math.floor(prospectForOne * ((showStackPrices or showFullStackPrices) and itemCount or 1))
    end
  end

  local millStatus = false
  local millValue
  if Auctionator.Mill then
    local itemID = GetItemInfoInstant(itemLink)
    millStatus = Auctionator.Mill.IsMillable(itemID)
    local millForOne = Auctionator.Mill.GetMillAuctionPrice(itemID)
    if millForOne ~= nil then
      millValue = math.floor(millForOne * ((showStackPrices or showFullStackPrices) and itemCount or 1))
    end
  end

  if Auctionator.Debug.IsOn() then
    tooltipFrame:AddDoubleLine("DBKey", dbKeys[1])
  end

  if vendorPrice ~= nil then
    Auctionator.Tooltip.AddVendorTip(tooltipFrame, vendorPrice, countString)
  end
  Auctionator.Tooltip.AddAuctionTip(tooltipFrame, auctionPrice, countString, cannotAuction)
  Auctionator.Tooltip.AddAuctionMeanTip(tooltipFrame, auctionMean, countString, cannotAuction)
  Auctionator.Tooltip.AddAuctionAgeTip(tooltipFrame, auctionAge, auctionPrice, showAgeUnknown)
  if disenchantStatus ~= nil then
    Auctionator.Tooltip.AddDisenchantTip(tooltipFrame, disenchantPrice, countString, disenchantStatus)

    if Auctionator.Constants.IsClassic and IsShiftKeyDown() and Auctionator.Config.Get(Auctionator.Config.Options.ENCHANT_TOOLTIPS) then
      for _, line in ipairs(Auctionator.Enchant.GetDisenchantBreakdown(itemLink, itemInfo)) do
        tooltipFrame:AddLine(line)
      end
    end
  end

  if prospectStatus then
    Auctionator.Tooltip.AddProspectTip(tooltipFrame, prospectValue, countString)
  end

  if millStatus then
    Auctionator.Tooltip.AddMillTip(tooltipFrame, millValue, countString)
  end

  tooltipFrame:Show()
end

-- Each itemEntry in itemEntries should contain
-- link
-- count
local isMultiplePricesPending = false
function Auctionator.Tooltip.ShowTipWithMultiplePricing(tooltipFrame, itemEntries)
  if isMultiplePricesPending or Auctionator.Database == nil then
    return
  end
  isMultiplePricesPending = true

  local total = 0
  local itemCount = 0
  local itemLinks = {}
  for _, itemEntry in ipairs(itemEntries) do
    table.insert(itemLinks, itemEntry.link)
  end

  Auctionator.Utilities.DBKeysFromMultipleLinks(itemLinks, function(allKeys)
    isMultiplePricesPending = false
    for index, dbKeys in ipairs(allKeys) do
      local itemEntry = itemEntries[index]

      tooltipFrame:AddLine(itemEntry.link)
      Auctionator.Tooltip.ShowTipWithPricingDBKey(tooltipFrame, dbKeys, itemEntry.link, itemEntry.count)
      local auctionPrice = Auctionator.Database:GetFirstPrice(dbKeys)
      if auctionPrice ~= nil then
        total = total + (auctionPrice * itemEntry.count)
      end
      itemCount = itemCount + itemEntry.count
    end

    tooltipFrame:AddLine("  ")

    tooltipFrame:AddDoubleLine(
      Auctionator.Locales.Apply("TOTAL_ITEMS_COLORED", itemCount),
      WHITE_FONT_COLOR:WrapTextInColorCode(
        Auctionator.Utilities.CreatePaddedMoneyString(total)
      )
    )

    tooltipFrame:Show()
  end)
end

function Auctionator.Tooltip.AddVendorTip(tooltipFrame, vendorPrice, countString)
  if Auctionator.Config.Get(Auctionator.Config.Options.VENDOR_TOOLTIPS) and vendorPrice > 0 then
    if Auctionator.Constants.IsClassic then
      GameTooltip_ClearMoney(tooltipFrame) -- Remove default price
    end

    tooltipFrame:AddDoubleLine(
      L("VENDOR") .. countString,
      WHITE_FONT_COLOR:WrapTextInColorCode(
        Auctionator.Utilities.CreatePaddedMoneyString(vendorPrice)
      )
    )
  end
end

function Auctionator.Tooltip.AddAuctionTip (tooltipFrame, auctionPrice, countString, cannotAuction)
  if Auctionator.Config.Get(Auctionator.Config.Options.AUCTION_TOOLTIPS) then
    if cannotAuction then
      tooltipFrame:AddDoubleLine(
        L("AUCTION") .. countString,
        WHITE_FONT_COLOR:WrapTextInColorCode(
          L("CANNOT_AUCTION") .. "  "
        )
      )
    elseif (auctionPrice ~= nil) then
      tooltipFrame:AddDoubleLine(
        L("AUCTION") .. countString,
        WHITE_FONT_COLOR:WrapTextInColorCode(
          Auctionator.Utilities.CreatePaddedMoneyString(auctionPrice)
        )
      )
    else
      tooltipFrame:AddDoubleLine(
        L("AUCTION") .. countString,
        WHITE_FONT_COLOR:WrapTextInColorCode(
          L("UNKNOWN") .. "  "
        )
      )
    end
  end
end

function Auctionator.Tooltip.AddAuctionMeanTip(tooltipFrame, auctionMean, countString, canAuction)
  if not Auctionator.Config.Get(Auctionator.Config.Options.AUCTION_MEAN_TOOLTIPS) then
    return
  end

  if auctionMean ~= nil then
    tooltipFrame:AddDoubleLine(
      L("AUCTION_MEAN") .. countString,
      WHITE_FONT_COLOR:WrapTextInColorCode(
        Auctionator.Utilities.CreatePaddedMoneyString(auctionMean)
      )
    )
  end
end

function Auctionator.Tooltip.AddAuctionAgeTip(tooltipFrame, auctionAge, auctionPrice, showUnknown)
  if not Auctionator.Config.Get(Auctionator.Config.Options.AUCTION_AGE_TOOLTIPS) then
    return
  end

  if auctionAge ~= nil then
    tooltipFrame:AddDoubleLine(AUCTIONATOR_L_AUCTION_AGE, WHITE_FONT_COLOR:WrapTextInColorCode(AUCTIONATOR_L_X_DAYS:format(tostring(auctionAge))))
  elseif auctionPrice ~= nil and showUnknown then
    tooltipFrame:AddDoubleLine(AUCTIONATOR_L_AUCTION_AGE, AUCTIONATOR_L_UNKNOWN)
  end
end

function Auctionator.Tooltip.AddDisenchantTip (
  tooltipFrame, disenchantPrice, countString, disenchantStatus
)
  if not Auctionator.Config.Get(Auctionator.Config.Options.ENCHANT_TOOLTIPS) then
    return
  end

  if disenchantPrice ~= nil then
    tooltipFrame:AddDoubleLine(
      L("DISENCHANT") .. countString,
      WHITE_FONT_COLOR:WrapTextInColorCode(
        Auctionator.Utilities.CreatePaddedMoneyString(disenchantPrice)
      )
    )
  elseif disenchantStatus.isDisenchantable and
         disenchantStatus.supportedXpac then
    tooltipFrame:AddDoubleLine(
      L("DISENCHANT") .. countString,
      WHITE_FONT_COLOR:WrapTextInColorCode(
        L("UNKNOWN") .. "  "
      )
    )
  end
end

function Auctionator.Tooltip.AddProspectTip (
  tooltipFrame, prospectValue, countString
)
  if not Auctionator.Config.Get(Auctionator.Config.Options.PROSPECT_TOOLTIPS) then
    return
  end

  if prospectValue ~= nil then
    tooltipFrame:AddDoubleLine(
      L("PROSPECT") .. countString,
      WHITE_FONT_COLOR:WrapTextInColorCode(
        Auctionator.Utilities.CreatePaddedMoneyString(prospectValue)
      )
    )
  else
    tooltipFrame:AddDoubleLine(
      L("PROSPECT") .. countString,
      WHITE_FONT_COLOR:WrapTextInColorCode(
        L("UNKNOWN") .. "  "
      )
    )
  end
end

function Auctionator.Tooltip.AddMillTip (
  tooltipFrame, millValue, countString
)
  if not Auctionator.Config.Get(Auctionator.Config.Options.MILL_TOOLTIPS) then
    return
  end

  if millValue ~= nil then
    tooltipFrame:AddDoubleLine(
      L("MILL") .. countString,
      WHITE_FONT_COLOR:WrapTextInColorCode(
        Auctionator.Utilities.CreatePaddedMoneyString(millValue)
      )
    )
  else
    tooltipFrame:AddDoubleLine(
      L("MILL") .. countString,
      WHITE_FONT_COLOR:WrapTextInColorCode(
        L("UNKNOWN") .. "  "
      )
    )
  end
end

local PET_TOOLTIP_SPACING = " "
function Auctionator.Tooltip.AddPetTip(
  speciesID
)
  Auctionator.Debug.Message("Auctionator.Tooltip.AddPetTip", speciesID)
  if not Auctionator.Config.Get(Auctionator.Config.Options.AUCTION_TOOLTIPS) or
     not Auctionator.Config.Get(Auctionator.Config.Options.PET_TOOLTIPS) then
    return
  end

  local key = "p:" .. tostring(speciesID)
  local price = Auctionator.Database:GetPrice(key)
  local auctionAge = Auctionator.Database:GetPriceAge(key)
  BattlePetTooltip:AddLine(" ")
  if price ~= nil then
    BattlePetTooltip:AddLine(
      L("AUCTION") .. PET_TOOLTIP_SPACING ..
      WHITE_FONT_COLOR:WrapTextInColorCode(
        Auctionator.Utilities.CreatePaddedMoneyString(price)
      )
    )
    if auctionAge ~= nil then
      BattlePetTooltip:AddLine(AUCTIONATOR_L_AUCTION_AGE .. PET_TOOLTIP_SPACING .. WHITE_FONT_COLOR:WrapTextInColorCode(AUCTIONATOR_L_X_DAYS:format(tostring(auctionAge))))
    elseif auctionPrice ~= nil then
      BattlePetTooltip:AddDoubleLine(AUCTIONATOR_L_AUCTION_AGE .. PET_TOOLTIP_SPACING .. AUCTIONATOR_L_UNKNOWN)
    end
  else
    BattlePetTooltip:AddLine(
      L("AUCTION") .. PET_TOOLTIP_SPACING ..
      WHITE_FONT_COLOR:WrapTextInColorCode(
        L("UNKNOWN")
      )
    )
  end
end
