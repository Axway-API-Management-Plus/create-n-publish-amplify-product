# Creates AssetMapping linking existing APIService, APIServiceRevision and APIServiceInstance
# note that APIServiceInstance ("apiServiceInstance") is an optional field.
{
    apiVersion: "v1alpha1",
    kind: "AssetMapping",
    metadata: {
        scope: {
            kind: "Asset",
            name: $asset_name,
        }
    },
    spec: {
        inputs: {
          stage: $stage_name,
          apiService: "management/\($env_name)/\($ENV.SRV_NAME)",
          apiServiceRevision: "management/\($env_name)/\($ENV.RVN_NAME)",
          apiServiceInstance: "management/\($env_name)/\($ENV.INS_NAME)",
        }
    }
}