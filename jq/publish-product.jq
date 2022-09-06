{
    group: "catalog",
    apiVersion: "v1alpha1",
    kind: "PublishedProduct",
    metadata: {
        scope: {
            kind: "Marketplace",
            name: .[0][0].name,
        }
    },
    spec: {
        product: {
            name: .[1][0].name
        }
    }
}