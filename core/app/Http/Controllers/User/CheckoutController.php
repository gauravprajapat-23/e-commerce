<?php

namespace App\Http\Controllers\User;

use App\Http\Controllers\Controller;
use App\Lib\CartManager;
use App\Models\Order;
use App\Models\ShippingAddress;
use App\Models\ShippingMethod;
use App\Models\Gateway;
use App\Models\GatewayCurrency;
use App\Constants\Status;
use Illuminate\Http\Request;

class CheckoutController extends Controller
{
    private $cartManager;

    public function __construct(CartManager $cartManager)
    {
        parent::__construct();
        $this->cartManager = $cartManager;
    }

    public function shippingInfo()
    {
        $pageTitle = 'Shipping Information';
        $shippingAddresses = ShippingAddress::where('user_id', auth()->id())->get();
        $countries = getCountries();

        return view('Template::user.checkout_steps.shipping_info', compact('pageTitle', 'shippingAddresses', 'countries'));
    }

    public function addShippingInfo(Request $request)
    {
        $ids = ShippingAddress::where('user_id', auth()->id())->pluck('id')->toArray();

        $request->validate([
            'shipping_address_id' => 'required|in:' . implode(',', $ids)
        ], [
            'shipping_address_id.required' => 'Shipping address is required',
            'shipping_address_id.in' => 'Invalid address selected'
        ]);

        $checkoutData = session('checkout_data');
        $checkoutData['shipping_address_id'] = $request->shipping_address_id;
        session()->put('checkout_data', $checkoutData);

        return to_route('user.checkout.delivery.methods');
    }

    public function deliveryMethods()
    {
        $pageTitle = 'Delivery Methods';
        $shippingMethods = ShippingMethod::active()->get();

        return view('Template::user.checkout_steps.shipping_methods', compact('pageTitle', 'shippingMethods'));
    }

    public function addDeliveryMethod(Request $request)
    {
        $ids = ShippingMethod::active()->pluck('id')->toArray();

        $request->validate([
            'shipping_method_id' => 'required|in:' . implode(',', $ids)
        ], [
            'shipping_method_id.required' => 'Delivery type field is required',
            'shipping_method_id.in' => 'Invalid delivery type selected'
        ]);

        $checkoutData = session('checkout_data');
        $checkoutData['shipping_method_id'] = $request->shipping_method_id;
        session()->put('checkout_data', $checkoutData);

        return to_route('user.checkout.payment.methods');
    }

    public function paymentMethods()
    {
        $pageTitle = 'Payment Methods';
        
        $gatewayCurrencies = GatewayCurrency::where('status', 1)
        ->with('method')
        ->orderBy('method_code')
        ->get();
    
    dd($gatewayCurrencies); // Check what data is being passed
    return view('Template::user.checkout_steps.payment_methods', compact('pageTitle', 'gatewayCurrencies'));
        // Get active automatic payment gateways
        $automaticGateways = Gateway::automatic()
            ->where('status', Status::ENABLE)
            ->with(['currencies' => function($query) {
                $query->where('status', Status::ENABLE);
            }])
            ->get();

        // Get active manual payment gateways
        $manualGateways = Gateway::manual()
            ->where('status', Status::ENABLE)
            ->with(['currencies' => function($query) {
                $query->where('status', Status::ENABLE);
            }])
            ->get();

        // Get all active gateway currencies
        $gatewayCurrencies = GatewayCurrency::where('status', Status::ENABLE)
            ->with('method')
            ->orderBy('method_code')
            ->get();

        // Calculate cart totals
        $subtotal = $this->cartManager->getSubtotal();
        $coupon = $this->appliedCoupon($this->cartManager->getCartData(), $subtotal);
        
        // Get shipping method if selected
        $shippingMethod = null;
        if (session('checkout_data')['shipping_method_id']) {
            $shippingMethod = ShippingMethod::find(session('checkout_data')['shipping_method_id']);
        }

        // Check if cart has physical products
        $hasPhysicalProduct = $this->cartManager->hasPhysicalProduct();

        return view('Template::user.checkout_steps.payment_methods', compact(
            'pageTitle',
            'automaticGateways',
            'manualGateways', 
            'gatewayCurrencies',
            'subtotal',
            'coupon',
            'shippingMethod',
            'hasPhysicalProduct'
        ));
    }

    public function confirmation($orderNumber)
    {
        $order = Order::where('order_number', $orderNumber)
            ->where('user_id', auth()->id())
            ->with([
                'deposit',
                'orderDetail.product',
                'orderDetail.productVariant',
                'appliedCoupon'
            ])
            ->first();

        $pageTitle = 'Order Number -' . $order->order_number;

        return view('Template::user.checkout_steps.confirmation', compact('pageTitle', 'order'));
    }

    private function appliedCoupon($cartData, $subtotal)
    {
        $coupon = session('coupon');

        if (!$coupon) {
            return null;
        }

        $coupon = $this->cartManager->getCouponByCode($coupon['code']);

        if (!$coupon) {
            return ['error' => "Applied coupon is invalid or expired"];
        }

        $checkCoupon = $this->cartManager->isValidCoupon($coupon, $subtotal, $cartData);

        if (isset($checkCoupon['error'])) {
            return $checkCoupon;
        }

        $coupon->discount_amount = $coupon->discountAmount($subtotal);

        return $coupon;
    }
}
