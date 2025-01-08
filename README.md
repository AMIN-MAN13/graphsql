# Finding the Shortest Path in Graphs

## Project Overview
This project focuses on implementing and analyzing various algorithms to compute the shortest path in graphs. Using real-world datasets, we compare the performance of different approaches, including User-Defined Functions (UDF) and Common Table Expressions (CTE), across diverse graph structures.

### Key Features
- Application of graph traversal techniques (BFS, DFS, Bidirectional BFS).
- Performance optimization through indexing and adjacency list representations.
- Comprehensive comparison of graph algorithms on peer-to-peer networks and road networks.
- Implementation in PostgreSQL with support from pgRouting and NetworkX.

---

## Datasets
The project utilizes two datasets:
1. **Gnutella Peer-to-Peer Network**:
   - Nodes: 6,301
   - Edges: 20,777
   - Characteristics: Sparse connections, low clustering coefficient.
2. **Texas Road Network**:
   - Nodes: 1,379,917
   - Edges: 1,921,660
   - Characteristics: High connectivity, real-world road network structure.

---

## Implementation Details
- **Tools and Technologies**: PostgreSQL, pgRouting, NetworkX, Python.
- **Key Techniques**:
  - **Indexing**: Accelerates query performance by optimizing node and edge lookups.
  - **Adjacency Lists**: Efficiently represent graph structures for scalable algorithms.
  - **Recursive Queries**: Explore graph paths using SQL's `WITH RECURSIVE`.

---

## Graph Traversal Methods
1. **Breadth-First Search (BFS)**:
   Explores all nodes at the current depth before moving deeper.
2. **Depth-First Search (DFS)**:
   Delves deep into a graph branch before backtracking.
3. **Bidirectional BFS**:
   Searches simultaneously from the source and target nodes for faster results.

---

## Results and Analysis
- **Performance Comparison**:
  - UDF methods generally outperform CTEs for deeper paths due to reduced overhead.
  - Adjacency representation shows mixed results, offering improvements in certain scenarios.
- **Observations**:
  - Bidirectional BFS exhibited the best performance in most cases, especially for larger datasets.
  - Recursive CTEs faced resource constraints with complex datasets.

---

## System Configuration
- **Processor**: Intel Core i7-9750H, 2.60 GHz, 6 Cores, 12 Threads.
- **Memory**: 16 GB RAM.
- **PostgreSQL Settings**:
  - Work Memory: 1250 MB
  - Effective Cache Size: 4 GB

---

## How to Run
1. Clone the repository:
   ```bash
   git clone https://github.com/AMIN-MAN13/graphsql.git
2. Set up the PostgreSQL database:
   Import datasets and create necessary tables.
   Configure pgRouting extensions.
3. Execute graph traversal algorithms using SQL queries or scripts.
