import StoreKit

extension ErrorHandler {
	
	enum SubscriptionError: Error {
		case purchaseCanceled
		case refundsCanceled
		case purchasePending
		case verificationError
		case error
		case productsError
		case restoreError
		case purchaseError
		
		var alertDescription: AlertDescription {
			return AlertDescription(title: "Subsctiption Error!",
									description: ErrorHandler.shared.loadError(for: self),
									action: LocalizationService.Buttons.getButtonTitle(of: .ok),
									cancel: Localization.empty)
		}
	}
	
	enum StoreError: Error {
		case storeKit(error: StoreKitError)
		case purchase(error: Product.PurchaseError)
		case verification(error: VerificationResult<Any>.VerificationError)
	}
	
	private func loadError(for key: SubscriptionError) -> String {
		switch key {
			case .purchaseCanceled:
				return Localization.ErrorsHandler.PurchaseError.purchaseIsCanceled
			case .refundsCanceled:
				return Localization.ErrorsHandler.PurchaseError.refundsCanceled
			case .purchasePending:
				return Localization.ErrorsHandler.PurchaseError.purchaseIsPending
			case .verificationError:
				return Localization.ErrorsHandler.PurchaseError.verificationError
			case .error:
				return Localization.ErrorsHandler.PurchaseError.error
			case .productsError:
				return Localization.ErrorsHandler.PurchaseError.productsError
			case .restoreError:
				return Localization.ErrorsHandler.PurchaseError.restorePurchseFailed
			case .purchaseError:
				return Localization.ErrorsHandler.PurchaseError.defaultPurchseError
		}
	}
	
	
	private func loadStoreError(for key: StoreError) -> String {
		switch key {
			case .storeKit(let storeKitError):
				switch storeKitError {
					case .networkError(_):
						return Localization.ErrorsHandler.PurchaseError.networkError
					case .systemError(_):
						return Localization.ErrorsHandler.PurchaseError.systemError
					case .userCancelled:
						return Localization.ErrorsHandler.PurchaseError.userCancelled
					case .notAvailableInStorefront:
						return Localization.ErrorsHandler.PurchaseError.notAvailableInStorefront
					default:
						return Localization.ErrorsHandler.PurchaseError.unknown
				}
			case .purchase(_):
				return Localization.ErrorsHandler.PurchaseError.productsError
			case .verification(_):
				return Localization.ErrorsHandler.PurchaseError.verificationError
		}
	}
	
	public func showSubsriptionAlertError(for key: SubscriptionError, at viewController: UIViewController, expreDate: String? = nil) {
		AlertManager.showPurchaseAlert(of: key, at: viewController)
	}

	public func showSubscriptionStoreError(for key: StoreError) {
		debugPrint("show error alert with key \(self.loadStoreError(for: key))")
	}
}

