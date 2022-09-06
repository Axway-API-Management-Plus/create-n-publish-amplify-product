{
    group: "catalog",
    apiVersion: "v1",
    kind: "Resource",
    title: env.articleTitle,
    metadata: {
        scope: {
            kind: "Product",
            name: .[0].name,
        }
    },
    spec: {
        data: {
          type: "text",
          content: env.articleContent
        },
        fileType: "markdown",
        contentType: "text/markdown"
    }
}
