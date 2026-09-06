import Foundation

/// Standalone smoke for `Quantity.swift`. Compile:
///   swiftc -parse-as-library ios/Adaptable/Adaptable/Utilities/Quantity.swift ios/quantity_smoke.swift -o /tmp/quantity-smoke
///   /tmp/quantity-smoke
@main
struct QuantitySmoke {
    static func main() {
        func expect(_ cond: Bool, _ msg: String) {
            if !cond {
                fputs("FAIL \(msg)\n", stderr)
                exit(1)
            }
        }

        expect(Quantity.scale("to taste", factor: 2) == "to taste", "to taste")
        expect(Quantity.scale("a handful", factor: 3) == "a handful", "handful")
        expect(Quantity.scale("2 × 150 g (5 oz)", factor: 2) == "4 × 150 g (5 oz)", "times")
        expect(Quantity.scale("1½", factor: 1.5) == "2 ¼", "unicode mixed")
        expect(Quantity.scale("1 ½", factor: 1.5) == "2 ¼", "spaced mixed")
        expect(Quantity.scale("1 ½ cups", factor: 1.5) == "2 ¼ cups", "cups")
        expect(Quantity.scale("3/4", factor: 2) == "1 ½", "lone fraction")
        expect(Quantity.scale("2,5 tbsp", factor: 2) == "5 tbsp", "comma decimal")
        expect(Quantity.formatNumber(2.25) == "2 ¼", "format 2.25")
        expect(Quantity.add("1 cup", "½ cup") == "1 ½ cup", "add cups")
        expect(Quantity.add("1 cup", "2 tbsp") == "1 cup + 2 tbsp", "unit clash")
        expect(Quantity.add("1 cup", "1 cup") == "1 cup", "identical")
        print("quantity swift ok")
    }
}
