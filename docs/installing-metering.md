# Installing and Configuring the Metering Operator

For the next steps, you will need access to an OpenShift cluster (4.3 or newer).

1. In OpenShift, create a namespace called `openshift-metering` if one does not exist, and label the namespace with `openshift.io/cluster-monitoring=true`.

2. Install the Metering Operator in the `openshift-metering` namespace, using the OpenShift web console (search for Metering in OperatorHub).

3. Create a key/value secret in the `openshift-metering` namespace called `metering-aws` where the keys are `aws-access-key-id` and `aws-secret-access-key` with your associated aws secret values.

4. Create a Metering Configuration that points to your bucket/path/ and region, and references the aws secret that you created above. It should look similar to the following:

```
apiVersion: metering.openshift.io/v1
kind: MeteringConfig
metadata:
  name: operator-metering
  namespace: openshift-metering
spec:
  storage:
    hive:
      s3:
        bucket: your-bucketname/path/
        createBucket: false
        region: us-east-1
        secretName: metering-aws
      type: s3
    type: hive
```

To check that Metering has been configured correctly, you can view & ensure that all of the pods are running & ready.
