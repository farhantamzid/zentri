import Testing
@testable import ZentriCore

@Test func aLineAnswerIsReadFieldByField() throws {
    let answer = """
    isTransaction: yes
    direction: debit
    amount: 1,250.00
    merchant: SHWAPNO GULSHAN
    balance: none
    date: 2026-11-17T09:12
    category: Groceries
    """
    let output = try #require(ModelLineAnswer.parse(answer))
    #expect(output.isTransaction)
    #expect(output.direction == "debit")
    #expect(output.amount == "1,250.00")
    #expect(output.merchant == "SHWAPNO GULSHAN")
    #expect(output.balance == nil)
    #expect(output.date == "2026-11-17T09:12")
    #expect(output.category == "Groceries")
}

@Test func aLineAnswerToleratesMarkdownAndCase() throws {
    let answer = """
    Here you go:
    - **IsTransaction**: Yes
    - **Amount**: "18.20"
    - Merchant: N/A
    """
    let output = try #require(ModelLineAnswer.parse(answer))
    #expect(output.isTransaction)
    #expect(output.amount == "18.20")
    #expect(output.merchant == nil)
}

@Test func aProseRefusalIsNotAnAnswer() {
    #expect(ModelLineAnswer.parse("Sorry, I can't help with that.") == nil)
}

@Test func aNonTransactionAnswerSaysSo() throws {
    let output = try #require(ModelLineAnswer.parse("isTransaction: no\ndirection: none"))
    #expect(!output.isTransaction)
    #expect(output.direction == nil)
}
