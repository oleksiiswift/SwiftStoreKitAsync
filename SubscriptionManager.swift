import StoreKit
import UIKit

typealias UpdateTransActionBlock = ((Transaction) async -> ())
typealias RenewalState = Product.SubscriptionInfo.RenewalState
var currentScene: UIScene?

class SubscriptionManager: NSObject {
	
	public var service = SubscriptionService()
	
	static var instance: SubscriptionManager {
		struct Static {
			static let instance: SubscriptionManager = SubscriptionManager()
		}
		return Static.instance
	}
	
	public var products: [Product] = []
	private var updateListener: Task <(), Never>? = nil
	
	private var purchasedPremium: Bool {
		get {
			return UserDefaults.standard.bool(forKey: "purchasePremium")
		} set {
			if purchasedPremium != newValue {
				let userInfo = ["purchasePremium": newValue]
				UserDefaults.standard.set(newValue, forKey: "purchasePremium")
				do {
					NotificationCenter.default.post(name: .premiumDidChange, object: nil, userInfo: userInfo)
				}
			}
		}
	}
	
	public var applicationDevelopmentSubscriptionStatus: ApplicationSubscriptionStatus {
		get {
			let statusValue: Int = UserDefaults.standard.integer(forKey: "subscriptionDevelopmentStatus")
			return ApplicationSubscriptionStatus(rawValue: statusValue)!
		} set {
			if applicationDevelopmentSubscriptionStatus != newValue {
				UserDefaults.standard.set(newValue.rawValue, forKey: "subscriptionDevelopmentStatus")
			}
		}
	}
	
	private var currentSubscription: Subscriptions? {
		get {
			let subscriptionID = UserDefaults.standard.string(forKey: "subscriptionID")
			if let subcription = Subscriptions.allCases.first(where: {$0.rawValue == subscriptionID}) {
				return subcription
			} else {
				return nil
			}
		} set {
			if currentSubscription != newValue {
				if let value = newValue {
					UserDefaults.standard.set(value.rawValue, forKey: "subscriptionID")
				}
			}
		}
	}
	
	public func initialize() {
		
		Task {
			do {
				let products = try await self.loadProducts()
				if !products.isEmpty {
					let isPurchased = try await self.purchaseProductsStatus()
					debugPrint("****")
					debugPrint("products is purchased -> \(isPurchased)")
					debugPrint("****")
				}
			} catch {
				self.setPurchasePremium(false)
				debugPrint("error load keys and subcription")
			}
		}
		self.setListener(finishTransaction: false) { transaction in
			await transaction.finish()
		}
	}
	
	public func loadProducts() async throws -> [Product] {
		let productsIDs: Set<String> = Set(Subscriptions.allCases.map({$0.rawValue}))
		let products = try await self.getPurchaseProducts(from: productsIDs)
		return products
	}
	
	public func purchase(product: Product) async throws -> Purchase {
		let purchase = try await self.service.purchase(product: product)
		return purchase
	}
	
	public func handleStatus(with product: Product) async throws -> Bool{
		let isPurchased = try await self.service.handleStatus(with: product)
		return isPurchased
	}
	
	public func getPurchaseProducts(from ids: Set<String>) async throws -> [Product] {
		try await self.service.loadProducts(from: ids)
	}
	
	public func setListener(finishTransaction: Bool = true, updateBlock: UpdateTransActionBlock?) {
		
		let task = Task.detached {
			
			for await result in Transaction.updates {
				do {
					let transaction = try self.service.checkVerificationResult(result)
					finishTransaction ? await transaction.finish() : ()
					await updateBlock?(transaction)
				} catch {
						ErrorHandler.shared.showSubsriptionAlertError(for: .verificationError, at: topController)
				}
			}
		}
		self.updateListener = task
	}
	
	public func restorePurchase() async throws -> Bool {
		return ((try? await AppStore.sync()) != nil)
	}
	
	public func isLifeTimeSubscription() async throws -> Bool {
		let productID = try await self.getCurrentSubscription()
		let subscription = Subscriptions.allCases.first(where: {$0.rawValue == productID.first})
		return subscription == Subscriptions.lifeTime
	}
	
	private func getCurrentSubscription(renewable: Bool = true) async throws -> [String] {
		return try await self.service.getCurrentSubsctiption(renewable: renewable).map({$0.productID})
	}
	
	public func purchaseProductsStatus() async throws -> Bool {
		
		do {
			let ids = try await self.getCurrentSubscription()
			
			let products = try await self.loadProducts()
			
			if !ids.isEmpty, let purchasedProductID = ids.first, try await service.isProductPurchased(productId: purchasedProductID) {
				
				if let product = products.first(where: {$0.id == purchasedProductID}) {
					let subscription = Subscriptions.allCases.first(where: {$0.rawValue == product.id})
					self.saveSubscription(subscription)
					self.setPurchasePremium(true)
					return true
				}
			}
			
			self.setPurchasePremium(false)
			self.saveSubscription(nil)
			return false
		} catch {
			debugPrint("error for cant load")
		}
		return false
	}
	
	public static func manageSubscription(in scene: UIWindowScene) async throws {
		try await AppStore.showManageSubscriptions(in: scene)
	}
}

extension SubscriptionManager {
	
	private func getProduct(by type: Subscriptions) -> Product? {
		
		if let product = self.products.first(where: {$0.id == type.rawValue}) {
			return product
		}
		return nil
	}
}


extension SubscriptionManager {
	
	public func setPurchasePremium(_ purchased: Bool) {
		self.purchasedPremium = purchased
	}
	public func getPurchasePremium() -> Bool {
		return self.purchasedPremium
	}

	public func purchasePremiumHandler(_ completionHandler: (_ status: StatusSubscription) -> Void) {
		switch self.applicationDevelopmentSubscriptionStatus {
			case .production:
				completionHandler(self.isLifeTimeSubscription() ? .lifetime : self.purchasedPremium ? .purchasedPremium : .nonPurchased)
			case .premiumSimulated:
				completionHandler(.purchasedPremium)
			case .lifeTimeSimulated:
				completionHandler(.lifetime)
			case .limitedSimulated:
				completionHandler(.nonPurchased)
		}
		
	}
	
	public func purchasePremiumStatus() -> StatusSubscription {
		switch self.applicationDevelopmentSubscriptionStatus {
			case .production:
				return self.isLifeTimeSubscription() ? .lifetime : self.purchasedPremium ? .purchasedPremium : .nonPurchased
			case .premiumSimulated:
				return .purchasedPremium
			case .lifeTimeSimulated:
				return .lifetime
			case .limitedSimulated:
				return .nonPurchased
		}
	}

	public func saveSubscription(_ currentSubscription: Subscriptions?) {
		self.currentSubscription = currentSubscription
	}
								 
	public func getCurrentSubscription() -> Subscriptions? {
		return self.currentSubscription
	}

	public func isLifeTimeSubscription() -> Bool {
		if let currentSubscription = currentSubscription {
			return currentSubscription.rawValue == Subscriptions.lifeTime.rawValue
		} else {
			return false
		}
	}
}

//	MARK: purchase prmium check
extension SubscriptionManager {
	
	public func checkForCurrentSubscription(completionHandler: @escaping (_ isSubscribe: Bool) -> Void) {
		
			Task {
				do {
					let isPurchasedPremium = try await self.purchaseProductsStatus()
					completionHandler(isPurchasedPremium)
				} catch {
					completionHandler(false)
				}
			}

	}
}

//	MARK: pruchase premium {
extension SubscriptionManager {
	
	public func purchasePremium(of type: Subscriptions, completionHadnler: @escaping (_ purchased: Bool) -> Void) {
		
		Task {
			let products = try await self.loadProducts()
			let product = products.first(where: {$0.id == type.rawValue})
			if let product = product {
				do {
					let purchase = try await self.purchase(product: product)
					if purchase.finishTransaction {
						self.saveSubscription(type)
						completionHadnler(true)
					} else {
						let isPurchasePremium = try await self.purchaseProductsStatus()
						completionHadnler(isPurchasePremium)
					}
				} catch {
					completionHadnler(false)
				}
			} else {
				completionHadnler(false)
			}
		}
	}
}

//	MARK: restore purchase
extension SubscriptionManager {

	public func restorePurchase(completionHandler: @escaping (_ restored: Bool,_ requested: Bool,_ date: Date?) -> Void) {
		Task {
			let requested = try await self.restorePurchase()
			if requested {
				let purchasePremium = try await self.purchaseProductsStatus()
				completionHandler(purchasePremium, requested, nil)
			} else {
				completionHandler(false, requested, nil)
			}
		}
	}
}

extension SubscriptionManager {
	
	public func changeCurrentSubscription() {
		
		Task {
			do {
				if let scene = currentScene as? UIWindowScene {
					try await SubscriptionManager.manageSubscription(in: scene)
				}
			} catch {
				debugPrint(error)
			}
		}
	}
}


extension SubscriptionManager {
	
	public func setAplicationDevelopmentSubscription(status: ApplicationSubscriptionStatus) {
		
		switch status {
			case .premiumSimulated, .lifeTimeSimulated:
				self.setPurchasePremium(true)
			case .limitedSimulated:
				self.setPurchasePremium(false)
			default:
				debugPrint("use basic production version")
		}
		
		self.applicationDevelopmentSubscriptionStatus = status
	}
}
