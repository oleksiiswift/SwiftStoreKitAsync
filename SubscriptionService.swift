import StoreKit

class SubscriptionService {
	
	@MainActor
	public func loadProducts(from productsIDs: Set<String>) async throws -> [Product] {
		
		do {
			if isProductsLoaded(productsIDs: productsIDs) {
				return SubscriptionManager.instance.products
			} else {
				let products = try await Product.products(for: productsIDs)
				SubscriptionManager.instance.products = products
				return products
			}
		} catch {
			throw ErrorHandler.StoreError.storeKit(error: error as! StoreKitError)
		}
	}
	
	private func isProductsLoaded(productsIDs: Set<String>) -> Bool {
		
		guard SubscriptionManager.instance.products.isEmpty else { return false }
		
		let loadedProductsIDs = Set(SubscriptionManager.instance.products.map({$0.id}))
		return loadedProductsIDs == productsIDs
	}
	
	public func isProductPurchsed(_ product: Product) async throws -> Bool {
		return try await self.isProductPurchased(productId: product.id)
	}
	
	public func isProductPurchased(productId: String) async throws -> Bool {
		
		guard let transactionResult = await Transaction.latest(for: productId) else { return false }
		
		let transaction = try self.checkVerificationResult(transactionResult)
		return transaction.revocationDate == nil && !transaction.isUpgraded
	}
	
	public func handleStatus(with product: Product) async throws -> Bool {
		let isProductPurchased = try await self.isProductPurchsed(product)
		return isProductPurchased
	}
}

extension SubscriptionService {
	
	public func purchase(product: Product, applicationToken: UUID? = nil, finishTransaction: Bool = true) async throws -> Purchase {
		
		let productQuainty = Product.PurchaseOption.quantity(1)
		var options: Set<Product.PurchaseOption> = []
		options.insert(productQuainty)
		
		if let applicationToken = applicationToken {
			let productToken = Product.PurchaseOption.appAccountToken(applicationToken)
			options.insert(productToken)
		}
		
		let purchaseResult = try await product.purchase(options: options)
		
		switch purchaseResult {
			case .success(let verification):
				let transaction = try self.checkVerificationResult(verification)
				finishTransaction ? await transaction.finish() : ()
				return Purchase(product: product, transaction: transaction, finishTransaction: !finishTransaction)
			case .userCancelled:
				throw ErrorHandler.SubscriptionError.refundsCanceled
			case .pending:
				throw ErrorHandler.SubscriptionError.purchasePending
			default:
				throw ErrorHandler.SubscriptionError.error
		}
	}
	
	public func getCurrentSubsctiption(renewable: Bool = true) async throws -> [Transaction] {
		
		var transactions: [Transaction] = []
		
		for await result in Transaction.currentEntitlements {
			do {
				let transaction = try self.checkVerificationResult(result)
				
				if transaction.productID == Subscriptions.lifeTime.rawValue {
					transactions.append(transaction)
				} else {
					transaction.productType == .autoRenewable || (!renewable && transaction.productType == .nonRenewable) ? transactions.append(transaction) : ()
				}
			} catch {
				throw error
			}
		}
		return transactions
	}
}

extension SubscriptionService {
	
	public func checkVerificationResult<T>(_ result: VerificationResult<T>) throws -> T {
		switch result {
			case .verified(let verified):
				return verified
			case .unverified(let unverifyed, _):
				return unverifyed
		}
	}
}


extension Product {
	
	var isActiveSubscription: Bool {
		get async {
			await (try? subscription?.status.first?.state == .subscribed) ?? false
		}
	}
	
	var isEligibleForIntroOffer: Bool {
		get async {
			await subscription?.isEligibleForIntroOffer ?? false
		}
	}
}


