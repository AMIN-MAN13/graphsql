<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GraphSQL Project README</title>
</head>
<body>
    <h1>GraphSQL: Finding Shortest Path in Graphs</h1>
    <p>
        This repository contains the implementation and analysis of graph traversal algorithms 
        using PostgreSQL with pgRouting. The project evaluates different approaches like BFS, 
        DFS, Bidirectional BFS, and Common Table Expressions (CTE) for finding the shortest 
        path in directed and undirected graphs.
    </p>

    <h2>How to Set Up and Run</h2>
    <ol>
        <li>
            <strong>Set Up the PostgreSQL Database:</strong>
            <ul>
                <li><strong>Import Datasets:</strong> 
                    Download the Gnutella and Texas Road Network datasets provided in the repository. 
                    Use PostgreSQL's <code>COPY</code> command or pgAdmin to load the datasets into the database.
                </li>
                <li><strong>Create Necessary Tables:</strong> 
                    Use the SQL scripts in the <code>setup</code> directory to create and initialize tables.
                </li>
                <li><strong>Configure pgRouting Extensions:</strong> 
                    Install pgRouting in your PostgreSQL instance and use its functions for graph traversal.
                </li>
            </ul>
        </li>
        <li>
            <strong>Run Graph Traversal Algorithms:</strong>
            <ul>
                <li>Execute algorithms like BFS, DFS, and Bidirectional BFS using SQL scripts in the 
                    <code>queries</code> directory.
                </li>
                <li>Example for Dijkstra:
                    <pre>
SELECT * FROM pgr_dijkstra(
    'SELECT id, source, target, cost FROM edges',
    start_node_id, end_node_id
);
                    </pre>
                </li>
            </ul>
        </li>
    </ol>

    <h2>Future Enhancements</h2>
    <ul>
        <li>Extend performance analysis for larger datasets with over 10 million nodes and edges.</li>
        <li>Introduce weighted traversal algorithms and explore advanced heuristics like A*.</li>
        <li>Implement real-time pathfinding for dynamic networks.</li>
        <li>Integrate visual tools for graph analysis using libraries like NetworkX or Gephi.</li>
    </ul>

    <h2>Authors</h2>
    <p>
        <strong>Amin Maneshi</strong><br>
        Master's Student in Information Technology at the University of Rostock<br>
        Specializing in Distributed Databases and Graph Algorithms<br>
        <a href="https://www.linkedin.com/in/amin-maneshi/" target="_blank">LinkedIn Profile</a> | 
        <a href="https://github.com/AMIN-MAN13/graphsql" target="_blank">GitHub Repository</a>
    </p>
</body>
</html>
