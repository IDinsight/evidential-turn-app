local turn = require("turn")
local JourneyGenerator = {}

-- Key function signature
-- Returns: full journey notebook string ready for turn.journeys.create()
function JourneyGenerator.generate(experiment_id, arms, add_consent_card)
    add_consent_card = add_consent_card == nil and true or add_consent_card
    local start_trigger = turn.assets.load("journey_fragments/start_trigger.md")
    local get_assignment_block = turn.assets.load("journey_fragments/get_assignment_calls.md")
    local consent_block = turn.assets.load("journey_fragments/consent_block.md")
    local jump_to_journey = turn.assets.load("journey_fragments/jump_to_journey.md")

    -- Build branch card with N then() clauses, and add corresponding jump_to_journey cards for each arm
    local branch_clauses = {}
    local jump_journey_cards = {}
    i = 1
    for arm, uuid in pairs(arms) do
        table.insert(branch_clauses,
            string.format("  then(StartJourney_%d when @contact.arm_assignment_id == \"%s\")", i, arm))
        local card = jump_to_journey
            :gsub("{{CARD_NAME}}", "StartJourney_" .. i)
            :gsub("{{STACK_UUID}}", uuid)
        table.insert(jump_journey_cards, card)
        i = i + 1
    end

    local branch_card = string.format(
        "card BranchBasedOnArms, \"BranchBasedOnArms\",\n  version: \"1\",\n  uuid: \"%s\",\n  code_generator: \"BRANCH\" do\n" .. table.concat(branch_clauses, "\n") .. "\nend\n",
        turn.uuid())

    local concatenated_journey = table.concat({
        start_trigger,
        add_consent_card and consent_block or "",
        get_assignment_block :gsub("{{EXPERIMENT_ID}}", experiment_id),
        branch_card,
        table.concat(jump_journey_cards, "\n"),
    }, "\n")

    return concatenated_journey
end

return JourneyGenerator