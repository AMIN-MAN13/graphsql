CREATE OR REPLACE FUNCTION "Gnutella".find_shortest_BFS_recursive_helper(
    source INT, target INT, frontier INT[][], visited INT[], max_depth INT, current_depth INT
)
RETURNS TABLE(path INT[], cost INT) AS $$
DECLARE
    next_frontier INT[][];
    current_path INT[];
    current_node INT;
    new_path INT[];
BEGIN
    IF current_depth > max_depth THEN
        RETURN; -- Maximum depth reached, stop search
    END IF;

    next_frontier := '{}'; -- Clear next frontier

    -- Loop through each path in the current frontier
    FOREACH current_path SLICE 1 IN ARRAY frontier LOOP
        -- Get the current node from the path
        current_node := current_path[array_length(current_path, 1)];

        -- Check if the current node is the target
        IF current_node = target THEN
            RETURN QUERY SELECT current_path, array_length(current_path, 1) - 1;
            RETURN; -- Path found, return immediately
        END IF;

        -- Find and add new paths extending from the current node
        FOR new_path IN
            SELECT current_path || destination_node_id
            FROM "Gnutella"."p2p-Gnutella08" -- Adjusted table name
            WHERE source_node_id = current_node
            AND NOT (visited @> ARRAY[destination_node_id])
        LOOP
            next_frontier := next_frontier || ARRAY[new_path];
            visited := array_append(visited, new_path[array_length(new_path, 1)]);
        END LOOP;
    END LOOP;

    -- Recur with next depth and the next frontier
    RETURN QUERY SELECT * FROM "Gnutella".find_shortest_BFS_recursive_helper(source, target, next_frontier, visited, max_depth, current_depth + 1);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "Gnutella".find_shortest_BFS_recursive(
    source INT, 
    target INT, 
    max_depth INT DEFAULT 10
)
RETURNS TABLE(path INT[], cost INT) AS $$
BEGIN
    -- Add 1 to max_depth when calling the helper function
    RETURN QUERY SELECT * FROM "Gnutella".find_shortest_BFS_recursive_helper(source, target, ARRAY[ARRAY[source]], ARRAY[source], max_depth + 1, 1);
END;
$$ LANGUAGE plpgsql;