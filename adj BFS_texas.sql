CREATE OR REPLACE FUNCTION "Road networks".find_shortest_BFS_adj(
    source INT, target INT, max_depth INT DEFAULT 10
)
RETURNS TABLE(path INT[], cost INT) AS $$
DECLARE
    frontier INT[][] := ARRAY[ARRAY[source]];
    next_frontier INT[][];
    visited INT[] := ARRAY[source];
    current_path INT[];
    current_node INT;
    destination_node INT;
    new_path INT[];
    current_depth INT := 1;
BEGIN
    -- Increment the max_depth by 1
    max_depth := max_depth + 1;

    -- While there are nodes to explore and the current depth is within limits
    WHILE array_length(frontier, 1) > 0 AND current_depth <= max_depth LOOP
        next_frontier := '{}'; -- Initialize next frontier

        -- Process each path in the current frontier
        FOREACH current_path SLICE 1 IN ARRAY frontier LOOP
            -- Identify the last node in the current path
            current_node := current_path[array_length(current_path, 1)];

            -- If the target node is found, return the path and its cost
            IF current_node = target THEN
                RETURN QUERY SELECT current_path, array_length(current_path, 1) - 1;
                RETURN; -- Exit after finding the target
            END IF;

            -- Explore all adjacent nodes
            FOR destination_node IN
                SELECT unnest_node
                FROM "Road networks"."roadNet_TX_Adjacency",
                     UNNEST(adjacency_nodes) AS unnest_node
                WHERE source_node_id = current_node
                AND unnest_node <> ALL(visited)
            LOOP
                -- Create new path extending current path with the adjacent node
                new_path := current_path || destination_node;
                next_frontier := next_frontier || ARRAY[new_path];
                visited := array_append(visited, destination_node); -- Mark as visited
            END LOOP;
        END LOOP;

        -- Move to the next level of the graph
        frontier := next_frontier;
        current_depth := current_depth + 1;
    END LOOP;

    -- In case the target is not found within max_depth
    RETURN;
END;
$$ LANGUAGE plpgsql;
