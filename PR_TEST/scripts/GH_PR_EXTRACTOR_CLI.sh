#!/bin/bash
# Input: List of repositories in GH org (hardcoded or passed as a file)
ORG_NAME="jsing120"
REPOS=("GH_TEST_PR_REPO")  # Add repo names here or read from a file

# Output file
OUTPUT_FILE="pr_review_extraction.txt"
echo "REPO_NAME | PR_NUMBER | COMMIT_ID | AUTHOR_NAME | REVIEWER_NAME | CODE FILE NAME : LINE_NO | IN_LINE_CODE_COMMENT | Code value" > "$OUTPUT_FILE"

# Loop through each repository
for REPO in "${REPOS[@]}"; do
    echo "Processing repository: $REPO"

    # Get all PRs (open and closed)
    PRS=$(gh pr list --repo "$ORG_NAME/$REPO" --state all --json number --jq '.[].number')

    # Loop through each PR
    for PR_NUMBER in $PRS; do
        echo "Fetching PR: $PR_NUMBER from $REPO"

        # Get PR details (commit ID and author)
        PR_DETAILS=$(gh pr view "$PR_NUMBER" --repo "$ORG_NAME/$REPO" --json commits,author --jq '{commit: .commits[-1].oid, author: .author.login}')

        if [[ -z "$PR_DETAILS" ]]; then
            echo "⚠️  ERROR: Could not retrieve PR details for PR $PR_NUMBER in $REPO"
            continue
        fi

        COMMIT_ID=$(echo "$PR_DETAILS" | jq -r '.commit')
        AUTHOR_NAME=$(echo "$PR_DETAILS" | jq -r '.author')




        # Process each comment safely
 # Fetch PR review comments
 RAW_COMMENTS=$(gh api repos/"$ORG_NAME"/"$REPO"/pulls/"$PR_NUMBER"/comments)


 # Debug: Print raw JSON to verify issues
 echo "DEBUG: Raw API response for PR $PR_NUMBER in $REPO"
 echo "$RAW_COMMENTS" | head -200 >debugRaw.json

 # Remove control characters BEFORE jq processes it
 CLEAN_COMMENTS=$(echo "$RAW_COMMENTS" )


 # Now process each comment safely
 echo "$CLEAN_COMMENTS" | jq -c '.[]' | while read -r COMMENT; do
     REVIEWER_NAME=$(echo "$COMMENT" | jq -r '.user.login // "UNKNOWN"')
     CODE_FILE=$(echo "$COMMENT" | jq -r '.path // "NO-CODE-FOR-TOP-LEVEL-REVIEW"')
     LINE_NO=$(echo "$COMMENT" | jq -r '.position // "NO-CODE-FOR-TOP-LEVEL-REVIEW"')

     # Handle multi-line diff_hunk safely
     INLINE_COMMENT=$(echo "$COMMENT" | jq -r '.body | @json' | sed 's/^"\(.*\)"$/\1/' | tr -d '\n')
     CODE_SNIPPET=$(echo "$COMMENT" | jq -r '.diff_hunk // "NO-CODE-FOR-TOP-LEVEL-REVIEW" | @json' | sed 's/^"\(.*\)"$/\1/' | tr -d '\n' | sed 's/\\n/ /g')

     # Append formatted data to output file
     echo "$REPO | $PR_NUMBER | $COMMIT_ID | $AUTHOR_NAME | $REVIEWER_NAME | $CODE_FILE : $LINE_NO | $INLINE_COMMENT | $CODE_SNIPPET" >> "$OUTPUT_FILE"
 done

    done
done

echo "Extraction completed. Output saved to $OUTPUT_FILE"