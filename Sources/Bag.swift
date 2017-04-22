//
//  Bag.swift
//  ReactiveSwift
//
//  Created by Justin Spahr-Summers on 2014-07-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Dispatch

/// An unordered, non-unique collection of values of type `Element`.
public struct Bag<Element> {
	/// A uniquely identifying token for removing a value that was inserted into a
	/// Bag.
	public struct Token: Equatable {
		fileprivate let timestamp: UInt64

		fileprivate init(_ timestamp: UInt64) {
			self.timestamp = timestamp
		}

		public static func ==(left: Token, right: Token) -> Bool {
			return left.timestamp == right.timestamp
		}
	}

	fileprivate struct ElementSlot {
		let value: Element
		let token: Token
	}

	fileprivate var elements: ContiguousArray<ElementSlot> = []
	private var lastTimestamp: UInt64 = 0

	public init() {}

	/// Insert the given value into `self`, and return a token that can
	/// later be passed to `remove(using:)`.
	///
	/// - parameters:
	///   - value: A value that will be inserted.
	@discardableResult
	public mutating func insert(_ value: Element) -> Token {
		var timestamp: UInt64 = 0

		repeat {
			// `DispatchTime` is expected to use monotonic clocks. That said a guard is
			// put here just in case.
			timestamp = DispatchTime.now().uptimeNanoseconds
		} while timestamp <= lastTimestamp

		lastTimestamp = timestamp

		let token = Token(timestamp)
		let element = ElementSlot(value: value, token: token)

		elements.append(element)
		return token
	}

	/// Remove a value, given the token returned from `insert()`.
	///
	/// - note: If the value has already been removed, nothing happens.
	///
	/// - parameters:
	///   - token: A token returned from a call to `insert()`.
	public mutating func remove(using token: Token) {
		// Removal is more likely for recent objects than old ones.
		for i in (elements.startIndex ..< elements.endIndex).reversed() {
			if elements[i].token == token {
				elements.remove(at: i)
				break
			}
		}
	}
}

extension Bag: RandomAccessCollection {
	public var startIndex: Int {
		return elements.startIndex
	}
	
	public var endIndex: Int {
		return elements.endIndex
	}

	public subscript(index: Int) -> Element {
		return elements[index].value
	}

	public func makeIterator() -> Iterator {
		return Iterator(elements)
	}

	/// An iterator of `Bag`.
	public struct Iterator: IteratorProtocol {
		private let base: ContiguousArray<ElementSlot>
		private var nextIndex: Int
		private let endIndex: Int

		fileprivate init(_ base: ContiguousArray<ElementSlot>) {
			self.base = base
			nextIndex = base.startIndex
			endIndex = base.endIndex
		}

		public mutating func next() -> Element? {
			let currentIndex = nextIndex

			if currentIndex < endIndex {
				nextIndex = currentIndex + 1
				return base[currentIndex].value
			}

			return nil
		}
	}
}

extension Bag.ElementSlot: CustomStringConvertible {
	var description: String {
		return "BagElement(\(value))"
	}
}
