{
    group: "catalog",
    apiVersion: "v1",
    kind: "Document",
    title: env.docTitle,
    metadata: {
        scope: {
            kind: "Product",
            name: env.PRODUCT_NAME,
        }
    },
    spec: {
        sections: [
        {
            title: env.docTitle,
            articles: [
                 .[] | {
                     kind: .kind, 
                     name: .name,
                     title: .title
                }
            ]
        }
        ]
    }
}