{
  group: "catalog",
  apiVersion: "v1alpha1",
  kind: "ProductPlan",
  title: "Basic Free Project Plan",
  spec: {
    product: .[0].name,
    description: "Free access to the api",
    type: "free",
    features: [
      {
        name: "Free API access"
      },
      {
        name: "10 Hours of support"
      }
    ],
    subscription: {
      interval: {
        type: "months",
        length: 1
      },
      renewal: "automatic",
      approval: "manual"
    }
  },
  state: "draft"
}