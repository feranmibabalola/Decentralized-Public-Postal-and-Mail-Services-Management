# Decentralized Public Postal and Mail Services Management

A comprehensive blockchain-based system for managing public postal services using Clarity smart contracts on the Stacks blockchain.

## Overview

This system provides decentralized management of postal services through five interconnected smart contracts that handle different aspects of mail and package delivery operations.

## System Architecture

### Core Contracts

1. **Mail Routing Contract** (`mail-routing.clar`)
    - Optimizes mail sorting and delivery routes
    - Manages processing centers and distribution hubs
    - Coordinates efficient mail flow between locations

2. **Package Tracking Contract** (`package-tracking.clar`)
    - Provides secure tracking of parcels and certified mail
    - Manages delivery verification and proof of delivery
    - Handles package status updates throughout the delivery process

3. **PO Box Management Contract** (`po-box-management.clar`)
    - Manages post office box assignments and availability
    - Handles rental payments and subscription management
    - Tracks box usage and maintenance schedules

4. **Mail Forwarding Contract** (`mail-forwarding.clar`)
    - Coordinates address changes and mail redirection
    - Manages temporary and permanent forwarding services
    - Handles forwarding fee calculations and payments

5. **Rural Delivery Contract** (`rural-delivery.clar`)
    - Optimizes postal service to remote and underserved areas
    - Manages special delivery routes and schedules
    - Coordinates resources for challenging delivery locations

## Key Features

- **Decentralized Management**: No single point of failure
- **Transparent Operations**: All transactions recorded on blockchain
- **Automated Payments**: Smart contract-based fee collection
- **Real-time Tracking**: Live updates on mail and package status
- **Efficient Routing**: Optimized delivery paths and resource allocation
- **Rural Coverage**: Specialized handling for remote area deliveries

## Data Structures

### Mail Items
- Unique tracking numbers
- Sender and recipient information
- Service type and priority level
- Current location and status
- Delivery timestamps

### Routes
- Origin and destination points
- Estimated delivery times
- Capacity and load optimization
- Cost calculations

### PO Boxes
- Box numbers and sizes
- Rental periods and payments
- Access permissions
- Maintenance records

## Security Features

- **Access Control**: Role-based permissions for postal workers
- **Data Integrity**: Immutable delivery records
- **Payment Security**: Automated escrow for services
- **Privacy Protection**: Encrypted sensitive information

## Installation

1. Install Clarinet CLI
2. Clone this repository
3. Run `clarinet check` to validate contracts
4. Deploy contracts to testnet/mainnet

## Testing

Run the test suite with:
\`\`\`bash
npm test
\`\`\`

## Usage Examples

### Tracking a Package
\`\`\`clarity
(contract-call? .package-tracking track-package u12345)
\`\`\`

### Renting a PO Box
\`\`\`clarity
(contract-call? .po-box-management rent-box u101 u12)
\`\`\`

### Setting Up Mail Forwarding
\`\`\`clarity
(contract-call? .mail-forwarding setup-forwarding "old-address" "new-address" u30)
\`\`\`

## Contract Interactions

Each contract operates independently but shares common data structures for seamless integration. The system supports:

- Mail item registration and tracking
- Route optimization and management
- Payment processing and verification
- Status updates and notifications
- Delivery confirmation and proof

## Error Handling

The system includes comprehensive error codes:
- `ERR-NOT-AUTHORIZED` (u100): Insufficient permissions
- `ERR-INVALID-INPUT` (u101): Invalid parameters
- `ERR-NOT-FOUND` (u102): Item/service not found
- `ERR-INSUFFICIENT-FUNDS` (u103): Payment required
- `ERR-ALREADY-EXISTS` (u104): Duplicate entry

## Future Enhancements

- Integration with IoT devices for real-time location tracking
- Machine learning for route optimization
- Mobile app integration
- International shipping coordination
- Environmental impact tracking

## License

MIT License - See LICENSE file for details

## Contributing

Please read CONTRIBUTING.md for guidelines on contributing to this project.
