import XCTest
@testable import StarCraftKit

final class PlayerTests: XCTestCase {
    func testPlayerFullName() {
        let playerWithFullName = Player(
            id: 1,
            name: "Serral",
            slug: "serral",
            firstName: "Joona",
            lastName: "Sotala",
            role: nil,
            nationality: "FI",
            imageURL: nil,
            currentTeam: nil,
            currentVideogame: nil,
            age: nil,
            birthday: nil,
            hometown: nil,
            active: nil
        )
        
        XCTAssertEqual(playerWithFullName.fullName, "Joona Sotala")
        XCTAssertEqual(playerWithFullName.displayName, "Joona Sotala")
        
        let playerWithoutFullName = Player(
            id: 2,
            name: "Innovation",
            slug: "innovation",
            firstName: nil,
            lastName: nil,
            role: nil,
            nationality: "KR",
            imageURL: nil,
            currentTeam: nil,
            currentVideogame: nil,
            age: nil,
            birthday: nil,
            hometown: nil,
            active: nil
        )
        
        XCTAssertNil(playerWithoutFullName.fullName)
        XCTAssertEqual(playerWithoutFullName.displayName, "Innovation")
    }
    
    func testPlayerHasTeam() {
        let team = Team(
            id: 1,
            name: "Team Liquid",
            slug: "team-liquid",
            acronym: "TL",
            imageURL: nil,
            location: "EU",
            players: nil,
            currentVideogame: nil,
            modifiedAt: nil
        )
        
        let playerWithTeam = Player(
            id: 1,
            name: "Clem",
            slug: "clem",
            firstName: nil,
            lastName: nil,
            role: nil,
            nationality: "FR",
            imageURL: nil,
            currentTeam: team,
            currentVideogame: nil,
            age: nil,
            birthday: nil,
            hometown: nil,
            active: nil
        )
        
        XCTAssertTrue(playerWithTeam.hasTeam)
        
        let playerWithoutTeam = Player(
            id: 2,
            name: "Maru",
            slug: "maru",
            firstName: nil,
            lastName: nil,
            role: nil,
            nationality: "KR",
            imageURL: nil,
            currentTeam: nil,
            currentVideogame: nil,
            age: nil,
            birthday: nil,
            hometown: nil,
            active: nil
        )
        
        XCTAssertFalse(playerWithoutTeam.hasTeam)
    }
    
    func testPlayerEquality() {
        let player1 = Player(
            id: 1,
            name: "Serral",
            slug: "serral",
            firstName: nil,
            lastName: nil,
            role: nil,
            nationality: "FI",
            imageURL: nil,
            currentTeam: nil,
            currentVideogame: nil,
            age: nil,
            birthday: nil,
            hometown: nil,
            active: nil
        )
        
        let player2 = Player(
            id: 1,
            name: "Serral Updated",
            slug: "serral",
            firstName: "Joona",
            lastName: "Sotala",
            role: nil,
            nationality: "FI",
            imageURL: nil,
            currentTeam: nil,
            currentVideogame: nil,
            age: nil,
            birthday: nil,
            hometown: nil,
            active: nil
        )
        
        let player3 = Player(
            id: 2,
            name: "Maru",
            slug: "maru",
            firstName: nil,
            lastName: nil,
            role: nil,
            nationality: "KR",
            imageURL: nil,
            currentTeam: nil,
            currentVideogame: nil,
            age: nil,
            birthday: nil,
            hometown: nil,
            active: nil
        )
        
        XCTAssertEqual(player1, player2) // Same ID
        XCTAssertNotEqual(player1, player3) // Different ID
    }
}