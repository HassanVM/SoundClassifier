// ParticipantAssignments.swift

import Foundation

struct CounterbalancingAssignment: Identifiable {
    let id: Int
    let participantNumber: Int
    let participantID: String
    let conditionOrderIndex: Int
    let modalityOrderIndex: Int
    let targetRotation: TargetRotation

    var conditionOrder: ConditionOrder { ConditionOrder.allOrders[conditionOrderIndex] }
    var modalityOrder: ModalityOrder   { ModalityOrder.allOrders[modalityOrderIndex] }

    var displayName: String { "Participant \(participantNumber)" }

    var summary: String {
        let c = conditionOrder
        let m = modalityOrder
        return """
        Exp 1: \(c.block1.displayName) → \(c.block2.displayName) → \(c.block3.displayName)
        Exp 2: \(m.block1.displayName) → \(m.block2.displayName) → \(m.block3.displayName)
        Target Rotation: \(targetRotation.rawValue)
        """
    }
}

enum CounterbalancingTable {

    static let all: [CounterbalancingAssignment] = (1...20).map { n in
        let i = n - 1
        return CounterbalancingAssignment(
            id: n,
            participantNumber: n,
            participantID: String(format: "P%02d", n),
            conditionOrderIndex: i % 6,
            modalityOrderIndex: i % 6,
            targetRotation: [TargetRotation.rotationA,
                             TargetRotation.rotationB,
                             TargetRotation.rotationC][i % 3]
        )
    }

    static func assignment(for number: Int) -> CounterbalancingAssignment? {
        all.first { $0.participantNumber == number }
    }
}
