type BillingLine = {
  quantity: number;
  unit_price: number;
  tax_rate: number;
  discount_type?: string;
  discount_value?: number;
};

function scaled(value: number, places: number): bigint {
  const [mantissa, exponent = '0'] = String(value).toLowerCase().split('e');
  const [whole, fraction = ''] = mantissa.split('.');
  const digits = BigInt(whole + fraction);
  const zeros = Number(exponent) + places - fraction.length;
  const factor = BigInt(10) ** BigInt(Math.abs(zeros));
  return zeros >= 0 ? digits * factor : roundedDivide(digits, factor);
}

function roundedDivide(value: bigint, divisor: bigint): bigint {
  return (value + divisor / BigInt(2)) / divisor;
}

export function billingLineTotals(item: BillingLine) {
  const base = roundedDivide(scaled(item.quantity, 3) * scaled(item.unit_price, 2), BigInt(1000));
  const discountValue = scaled(item.discount_value ?? 0, 2);
  const requestedDiscount = item.discount_type === 'percent'
    ? roundedDivide(base * discountValue, BigInt(10000))
    : discountValue;
  const discount = requestedDiscount < base ? requestedDiscount : base;
  const taxable = base - discount;
  const tax = roundedDivide(taxable * scaled(item.tax_rate, 2), BigInt(10000));
  return {base:Number(base)/100, discount:Number(discount)/100, tax:Number(tax)/100, total:Number(taxable+tax)/100};
}
