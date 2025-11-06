# Continuum-Architecture

## Overview

`continuum-architecture` is a collection of tools and scripts to automate the deployment and management of lightweight Kubernetes clusters (k3s) on cloud-edge architectures. The project integrates a service for the automatic distribution of VPN certificates to ensure secure communication between nodes and tools to simplify the management of worker nodes in the cluster.

## Repository Structure

- ### [K3s Cluster Setup](./K3s%20Cluster%20Setup)  
  Contains scripts to automatically create and configure a k3s Kubernetes cluster, including master initialization and worker node preparation.

- ### [Certificate Generation Service](./Certificate%20Generation%20Service)  
  Service dedicated to the automatic distribution of VPN certificates necessary to establish secure connections between cluster nodes.

- ### [Node Manager](./Node%20Manager)  
  Tools to manage automatic join and maintenance of worker nodes using the distributed VPN certificates, facilitating cluster scalability and security.

## Prerequisites

- **OpenVPN** must be installed on the system to enable secure VPN communication between nodes.  
- Linux environment compatible with k3s, with network and resource requirements met.

## Quick Start

1. Install OpenVPN on your system.  
2. Run the scripts in `K3s Cluster Setup` to deploy the Kubernetes cluster.  
3. Start the `Certificate Generation Service` to automate the distribution of VPN certificates.  
4. Use `Node Manager` to securely and automatically add worker nodes to the cluster.

---

For more detailed instructions, please refer to the individual README files in each folder.
