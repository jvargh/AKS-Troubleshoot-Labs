# AKS-Troubleshoot-Labs

As Kubernetes continues to gain popularity as a container orchestration tool, more and more organizations are turning to Azure Kubernetes Service (AKS) to manage their workloads. However, managing AKS clusters can be challenging, especially when it comes to troubleshooting issues that arise.

In this technical blog post article, we will explore AKS Triage and Troubleshooting Labs, a series of exercises designed to help users learn how to diagnose and resolve common issues that arise when managing AKS clusters.

We will start with AKS setup instructions to build the environment from scratch, ensuring a working setup. Then, we will dive into six different labs that cover a range of troubleshooting scenarios, from connectivity issues to DNS and external access failures, to endpoint connectivity issues across virtual networks.

**Lab 1** focuses on troubleshooting and resolving connectivity issues between pods and services within the same Kubernetes cluster. The cluster layout is a simple one, with two pods created by their respective deployments and exposed using Cluster IP Service. The objective is to diagnose any issues with connectivity and to resolve them, using common tools and techniques.

**Lab 2** involves troubleshooting and resolving Pod DNS lookups and DNS resolution failures. The cluster layout is more complex, with an NSG applied to the AKS subnet and Network Policies in effect. The goal is to diagnose and resolve issues with DNS lookups and DNS resolution failures, by first setting up the environment and then following a series of steps.

**Lab 3** focuses on troubleshooting connectivity issues between pods and endpoints in other virtual networks. The cluster layout involves two VNets, one for AKS and the other for a VM Linux host, with a Private Endpoint joining the two VNets. The objective is to diagnose and resolve connectivity issues, using tools and techniques specific to this scenario.

**Lab 4** aims to identify and resolve issues where traffic directed through a Load Balancer fails to reach the intended pod. The focus is on troubleshooting the problem until it is resolved, using a Web Server Pod with a Service of type LoadBalancer allowing External IP access. The cluster layout has an NSG applied to the AKS subnet and Network Policies in effect.

**Lab 5** involves diagnosing an issue where a non-working application running on the cluster fails with a timeout error when a curl command is executed. The objective is to use tools on the Linux node hosting the application to diagnose the issue and to resolve it.

Finally, **Lab 6** focuses on enabling Container Insights to view container performance and Container Diagnostics to view logging. The objective is to set up these tools so that they can be used for monitoring and troubleshooting containerized applications running on the AKS cluster.

Overall, these labs provide a comprehensive set of scenarios and tools for diagnosing and troubleshooting issues related to AKS. They cover a range of common issues that can arise when running containerized applications in a Kubernetes environment, and they provide step-by-step guidance on how to resolve these issues using a variety of tools and techniques.
