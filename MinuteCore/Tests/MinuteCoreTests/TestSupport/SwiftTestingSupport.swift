import Testing

func expectEqual<T: Equatable>(_ lhs: T, _ rhs: T) {
    #expect(lhs == rhs)
}
