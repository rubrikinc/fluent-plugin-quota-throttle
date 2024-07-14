for i in {1..20}; do
	echo "{\"group\": \"group1\", \"user_id\": \"user1\", \"message\": \"Test log $i\"}" | fluent-cat test.default
done
for i in {1..20}; do
	echo "{\"group\": \"group1\", \"user_id\": \"user3\", \"message\": \"Test log $i\"}" | fluent-cat test.default
done
for i in {1..20}; do
	echo "{\"group\": \"group1\", \"user_id\": \"user2\", \"message\": \"Test log $i\"}" | fluent-cat test.default
done

