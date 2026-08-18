import Foundation

struct IngredientSwap: Identifiable, Equatable {
    let name: String
    let note: String
    var id: String { name }
}

/// Common pantry swaps so a cook can keep going without leaving the step.
enum Substitutions {
    static func suggestions(for item: String) -> [IngredientSwap] {
        let key = item.lowercased()
        for (needles, swaps) in catalog where needles.contains(where: { key.contains($0) }) {
            return swaps.filter { !$0.name.lowercased().contains(key) && key != $0.name.lowercased() }
        }
        return []
    }

    private static let catalog: [([String], [IngredientSwap])] = [
        (["feta"], [
            IngredientSwap(name: "Goat cheese", note: "Similar tang, melts a bit creamier"),
            IngredientSwap(name: "Ricotta", note: "Milder — add extra salt and lemon"),
            IngredientSwap(name: "Cream cheese", note: "Richer, less salty"),
        ]),
        (["cherry tomato", "grape tomato", "tomato"], [
            IngredientSwap(name: "Grape tomatoes", note: "Same roast, slightly sweeter"),
            IngredientSwap(name: "Chopped plum tomatoes", note: "Drain extra liquid"),
            IngredientSwap(name: "Canned whole tomatoes", note: "Drain well, roast a little longer"),
        ]),
        (["basil"], [
            IngredientSwap(name: "Parsley", note: "Fresh finish, less sweet"),
            IngredientSwap(name: "Baby spinach", note: "Wilt in at the end"),
            IngredientSwap(name: "Oregano", note: "Use half as much if dried"),
        ]),
        (["penne", "fusilli", "rigatoni", "pasta", "spaghetti", "tagliatelle", "noodle"], [
            IngredientSwap(name: "Any short pasta", note: "Cook to al dente, same weight"),
            IngredientSwap(name: "Spaghetti", note: "Same weight, toss well"),
            IngredientSwap(name: "Gluten-free pasta", note: "Watch the boil — it overcooks fast"),
        ]),
        (["olive oil"], [
            IngredientSwap(name: "Avocado oil", note: "High heat, neutral flavor"),
            IngredientSwap(name: "Neutral oil", note: "Vegetable or canola"),
            IngredientSwap(name: "Butter", note: "Richer; watch the smoke point"),
        ]),
        (["chili flake", "red pepper flake", "chilli flake"], [
            IngredientSwap(name: "Cayenne", note: "Start with a pinch"),
            IngredientSwap(name: "Hot paprika", note: "Color + milder heat"),
            IngredientSwap(name: "Black pepper", note: "Warmth without chili"),
        ]),
        (["garlic"], [
            IngredientSwap(name: "Garlic powder", note: "¼ tsp powder per clove"),
            IngredientSwap(name: "Shallot", note: "Milder, use a bit more"),
        ]),
        (["butter"], [
            IngredientSwap(name: "Olive oil", note: "Dairy-free, slightly less rich"),
            IngredientSwap(name: "Ghee", note: "Same richness, higher smoke point"),
        ]),
        (["cream", "heavy cream"], [
            IngredientSwap(name: "Coconut milk", note: "Full-fat, dairy-free"),
            IngredientSwap(name: "Half-and-half + butter", note: "Close stand-in"),
        ]),
        (["parmesan", "pecorino", "parmigiano"], [
            IngredientSwap(name: "Pecorino", note: "Saltier, sharper"),
            IngredientSwap(name: "Grana Padano", note: "Milder hard cheese"),
            IngredientSwap(name: "Nutritional yeast", note: "Dairy-free, use less"),
        ]),
        (["soy sauce", "tamari"], [
            IngredientSwap(name: "Tamari", note: "Gluten-free, similar salt"),
            IngredientSwap(name: "Coconut aminos", note: "Sweeter, use a bit more"),
        ]),
        (["chicken"], [
            IngredientSwap(name: "Turkey", note: "Same cook time, leaner"),
            IngredientSwap(name: "Firm tofu", note: "Press well, shorter cook"),
            IngredientSwap(name: "Chickpeas", note: "Pantry protein swap"),
        ]),
        (["salmon", "cod", "tuna"], [
            IngredientSwap(name: "Any firm white fish", note: "Check doneness a minute early"),
            IngredientSwap(name: "Trout", note: "Similar cook time"),
        ]),
        (["lemon"], [
            IngredientSwap(name: "Lime", note: "Same acidity, different aroma"),
            IngredientSwap(name: "White wine vinegar", note: "Start with half"),
        ]),
        (["lime"], [
            IngredientSwap(name: "Lemon", note: "Same acidity"),
        ]),
        (["onion"], [
            IngredientSwap(name: "Shallot", note: "Milder, use a few"),
            IngredientSwap(name: "Leek", note: "White and light-green parts"),
        ]),
        (["spinach", "kale"], [
            IngredientSwap(name: "Kale", note: "Strip stems, cook a minute longer"),
            IngredientSwap(name: "Baby spinach", note: "Wilts in seconds"),
            IngredientSwap(name: "Frozen spinach", note: "Squeeze dry"),
        ]),
        (["cilantro", "coriander"], [
            IngredientSwap(name: "Parsley", note: "If cilantro tastes soapy"),
            IngredientSwap(name: "Green onion", note: "Fresh bite"),
        ]),
        (["peanut butter", "peanut"], [
            IngredientSwap(name: "Almond butter", note: "Slightly less sweet"),
            IngredientSwap(name: "Sunflower seed butter", note: "Nut-free"),
            IngredientSwap(name: "Tahini", note: "Earthier, thin with water"),
        ]),
        (["egg"], [
            IngredientSwap(name: "Just-egg or flax egg", note: "Best in baking, not scrambles"),
        ]),
        (["yogurt"], [
            IngredientSwap(name: "Sour cream", note: "Richer"),
            IngredientSwap(name: "Coconut yogurt", note: "Dairy-free"),
        ]),
        (["wine"], [
            IngredientSwap(name: "Broth + splash of vinegar", note: "Same deglaze, no alcohol"),
            IngredientSwap(name: "Stock", note: "Skip the acidity"),
        ]),
        (["panko", "breadcrumb"], [
            IngredientSwap(name: "Crushed crackers", note: "Same crunch"),
            IngredientSwap(name: "Skip it", note: "Still great without the crust"),
        ]),
    ]
}
