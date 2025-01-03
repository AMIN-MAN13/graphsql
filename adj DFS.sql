CREATE OR REPLACE FUNCTION "Gnutella".recursive_dfs_adj(
    current_node INT,
    target INT,
    max_depth INT,
    current_depth INT,
    current_path INT[]
)
RETURNS VOID AS $$
DECLARE
    neighbors RECORD;
BEGIN
    -- Check if the current node is the target node.
    IF current_node = target THEN
        INSERT INTO temp_path_cost (path, cost) VALUES (current_path, current_depth - 1);
        RETURN;
    END IF;

    -- If the depth limit is reached, skip this path.
    IF current_depth >= max_depth THEN
        RETURN;
    END IF;

    -- Find and recursively call neighbors not in the current path using the adjacency list.
    FOR neighbors IN
        SELECT unnest_node AS destination_node_id
        FROM "Gnutella".adjacency_list,
             UNNEST(destination_node_id) AS unnest_node
        WHERE source_node_id = current_node
        AND unnest_node <> ALL(current_path)
    LOOP
        PERFORM "Gnutella".recursive_dfs_adj(
            neighbors.destination_node_id,
            target,
            max_depth,
            current_depth + 1,
            current_path || neighbors.destination_node_id
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION "Gnutella".find_shortest_path(
    source INT,
    target INT,
    max_depth INT
)
RETURNS TABLE(path INT[], cost INT) AS $$
DECLARE
    shortest_path INT[];
    shortest_cost INT := max_depth + 1;
BEGIN
    -- Create a temporary table.
    EXECUTE 'CREATE TEMPORARY TABLE IF NOT EXISTS temp_path_cost (path INT[], cost INT) ON COMMIT DROP';

    -- Start the recursive DFS with the initial node.
    PERFORM "Gnutella".recursive_dfs_adj(source, target, max_depth + 1, 1, ARRAY[source]);

    -- Retrieve the shortest path from the temp table.
    SELECT tpc.path, tpc.cost
    INTO shortest_path, shortest_cost
    FROM temp_path_cost tpc
    ORDER BY tpc.cost
    LIMIT 1;

    -- Return the shortest path found, if any.
    IF shortest_path IS NOT NULL THEN
        RETURN QUERY SELECT shortest_path, shortest_cost;
    ELSE
        -- Return empty path and NULL cost if no path is found.
        RETURN QUERY SELECT '{}'::INT[], NULL::INT;
    END IF;

    RETURN;
END;
$$ LANGUAGE plpgsql;
