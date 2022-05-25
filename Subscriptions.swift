import StoreKit

enum StatusSubscription {
	case lifetime
	case purchasedPremium
	case nonPurchased
}

enum Subscriptions: String, CaseIterable {

	case month = 	"com.month"
	case year = 	"com.year"
	case week = 	"com.week"
	case lifeTime = "com.lifetime"
}

struct Purchase {
	
	public let product: Product
	public let transaction: Transaction
	public let finishTransaction: Bool
	
	public var productID: String {
		transaction.productID
	}
	
	public var quantity: Int {
		transaction.purchasedQuantity
	}
	
	public func didFinishTransaction() async {
		await transaction.finish()
	}
}

struct CurrentSubscriptionModel {
	
	var expireDate: String
	var id: String
	var subscription: Subscriptions
	
	init(expireDate: String, id: String, subscription: Subscriptions) {
		self.expireDate = expireDate
		self.id = id
		self.subscription = subscription
	}
}
