{
    group: "catalog",
    apiVersion: "v1alpha1",
    kind: "ReleaseTag",
    metadata: {
        scope: {
            kind: "Asset",
            name: .[0][0].name,
        }
    },
    spec: {
        releaseType: "major"
    }
}