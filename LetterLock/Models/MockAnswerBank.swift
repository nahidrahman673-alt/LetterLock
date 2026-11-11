//
//  MockAnswerBank.swift
//  LetterLock
//
//  Prototype only: sample answers for the simulated players.
//

import Foundation

enum MockAnswerBank {
    private static let bank: [String: [String]] = [
        "Boy's Name": words("Adam|Aaron|Ben|Bilal|Charlie|Daniel|Ethan|Finn|George|Harry|Isaac|Jack|James|Kai|Leo|Liam|Max|Noah|Oscar|Omar|Peter|Quentin|Ryan|Sam|Theo|Umar|Victor|William|Xavier|Yusuf|Zac"),
        "Girl's Name": words("Amelia|Ava|Bella|Chloe|Daisy|Ella|Emily|Freya|Grace|Hannah|Isla|Jade|Kate|Lily|Mia|Nora|Olivia|Poppy|Queenie|Ruby|Sophie|Tara|Una|Violet|Willow|Xena|Yasmin|Zara"),
        "Country": words("Australia|Argentina|Brazil|Canada|Chile|Denmark|Egypt|France|Germany|Greece|Hungary|India|Italy|Japan|Kenya|Lebanon|Mexico|Norway|Oman|Peru|Qatar|Russia|Spain|Turkey|Uganda|Vietnam|Wales|Yemen|Zambia"),
        "City": words("Amsterdam|Athens|Berlin|Boston|Cairo|Dublin|Edinburgh|Florence|Glasgow|Houston|Istanbul|Jakarta|Kyoto|London|Lisbon|Madrid|Nairobi|Oslo|Paris|Quebec|Rome|Sydney|Tokyo|Utrecht|Venice|Warsaw|York|Zurich"),
        "Animal": words("Ant|Alligator|Bear|Cat|Cheetah|Dog|Dolphin|Eagle|Fox|Giraffe|Horse|Iguana|Jaguar|Kangaroo|Lion|Monkey|Newt|Owl|Panda|Quail|Rabbit|Snake|Tiger|Urchin|Vulture|Whale|Yak|Zebra"),
        "Food/Drink": words("Apple|Bagel|Burger|Coffee|Cheese|Donut|Egg|Fries|Grapes|Hummus|Ice cream|Jam|Kebab|Lemonade|Mango|Noodles|Orange|Pizza|Quiche|Rice|Sushi|Tea|Udon|Vanilla|Waffle|Yogurt|Ziti"),
        "Movies/Series": words("Avatar|Barbie|Casablanca|Dune|Elf|Friends|Gladiator|Heat|Inception|Jaws|Kill Bill|Lost|Mad Men|Narcos|Oppenheimer|Psycho|Rocky|Seinfeld|Titanic|Up|Vertigo|Wednesday|You|Zodiac"),
        "Book/Movie Character": words("Aladdin|Bilbo|Batman|Cinderella|Dracula|Elsa|Frodo|Gandalf|Hermione|Indiana Jones|Joker|Katniss|Luke Skywalker|Mulan|Nemo|Olaf|Pikachu|Rapunzel|Shrek|Tarzan|Ursula|Voldemort|Woody|Yoda|Zorro"),
        "Celebrity": words("Adele|Beyonce|Cher|Drake|Eminem|Ed Sheeran|Fergie|Gaga|Harry Styles|Ice Cube|Jay-Z|Kanye|Lizzo|Madonna|Nicki Minaj|Oprah|Pink|Rihanna|Shakira|Taylor Swift|Usher|Vin Diesel|Will Smith|Zendaya"),
        "Brand": words("Adidas|Apple|BMW|Chanel|Coca-Cola|Dior|Esso|Ford|Gucci|Honda|IKEA|Jeep|KitKat|Lego|Nike|Nokia|Oreo|Puma|Qantas|Rolex|Samsung|Tesla|Uber|Vans|Walmart|Xbox|Yamaha|Zara"),
    ]

    /// A plausible answer for `category` starting with `letter`, or blank roughly a third of the time.
    static func answer(for category: String, letter: String) -> String {
        guard Double.random(in: 0..<1) > 0.3 else { return "" }
        let options = bank[category, default: []].filter { $0.uppercased().hasPrefix(letter) }
        return options.randomElement() ?? ""
    }

    private static func words(_ list: String) -> [String] {
        list.split(separator: "|").map(String.init)
    }
}
