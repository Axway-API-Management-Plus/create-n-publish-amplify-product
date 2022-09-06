{
  group: "catalog",
  apiVersion: "v1alpha1",
  kind: "Quota",
  title: $quota_title,
  metadata: {
    scope: {
      kind: "ProductPlan",
      name: $product_plan_name
    }
  },
  spec: {
    unit: "transactions",
    pricing: {
      type: "unlimited"
      },
    resources: [
    ]
  }
}
