# GitHub

Every call goes through `gh`. Below, `{o}/{r}` is the repository and `{n}` the PR number. Request bodies go in JSON files passed with `--input`, which keeps multi-line text and quotes intact. GraphQL requests use the same shape: a file holding `{"query": "...", "variables": {...}}`, sent with `gh api graphql --input <file>`.

## Read

- **You:** `gh api user --jq .login`.
- **PR of a branch:** here `{o}/{r}` is the branch's own remote, from `git remote get-url "$(git config branch.{branch}.remote)"`. Run `gh pr list -R {o}/{r} --head {branch} --state open --json number,author,headRepositoryOwner`. `--head` matches the branch name in forks too, so keep only the PRs whose `headRepositoryOwner.login` is `{o}`, both lowercased: GitHub logins ignore case, remote URLs keep whatever case was typed. When `{o}/{r}` is a fork, its PRs live in the parent: `gh api repos/{o}/{r} --jq '.parent.full_name // empty'` names it, and the same list with the same filter runs there too. A plain `gh pr view` finds a fork's PR only when an `upstream` remote exists, so it is no substitute.
- **Metadata:** `gh pr view {n} -R {o}/{r} --json number,url,title,body,author,state,isDraft,headRefName,headRefOid,baseRefName`. The base commit comes from `gh api repos/{o}/{r}/pulls/{n} --jq .base.sha`: older `gh` releases reject `--json baseRefOid`.
- **Diff:** `gh pr diff {n} -R {o}/{r}`. Line anchors must land in this diff, so take it from here; read the surrounding code from the local clone.
- **Threads:**
  ```graphql
  query($owner:String!,$name:String!,$n:Int!){repository(owner:$owner,name:$name){pullRequest(number:$n){
    id headRefOid
    reviewThreads(first:100){nodes{id isResolved isOutdated path line diffSide
      comments(first:50){nodes{databaseId author{login} body createdAt url}}}}}}}
  ```
  A thread needing a response has `isResolved: false`. `isOutdated: true` means later commits moved the code it points at: read the current code before judging it.
- **General comments and reviews:** `gh pr view {n} -R {o}/{r} --json comments,reviews`.
- **Pending review:** `gh api repos/{o}/{r}/pulls/{n}/reviews --jq '.[] | select(.state=="PENDING")'`. GitHub allows one pending review per user per PR.

## Line anchors

An inline comment carries `path`, `line` and `side`. `side` is `RIGHT` for added and unchanged lines, numbered as in the new file, and `LEFT` for removed lines, numbered as in the old file. A range adds `start_line` and `start_side`. A line outside every hunk of the diff is rejected, so its comment goes into the review body instead, naming the file and line. While a review is pending, REST returns its comments with `line: null`; check the anchor by `position` and the last line of `diff_hunk`, which is the commented line.

## Post a review

One call, from a payload file:

```json
{
  "commit_id": "<headRefOid>",
  "event": "COMMENT",
  "body": "<summary>",
  "comments": [
    { "path": "src/Foo.cs", "line": 42, "side": "RIGHT", "body": "<comment>" }
  ]
}
```

`gh api --method POST repos/{o}/{r}/pulls/{n}/reviews --input <file>`

`event` is `COMMENT`, `APPROVE` or `REQUEST_CHANGES`. `COMMENT` and `REQUEST_CHANGES` require a non-empty `body`. GitHub rejects `APPROVE` and `REQUEST_CHANGES` on a PR the user authored.

## Reply to threads

Replies go out as one review so they arrive as one notification. Run in order, each a GraphQL request:

1. Open a pending review: `mutation($pr:ID!){addPullRequestReview(input:{pullRequestId:$pr}){pullRequestReview{id}}}`, with `$pr` the PR's `id` from the thread query.
2. For each reply: `mutation($rev:ID!,$t:ID!,$b:String!){addPullRequestReviewThreadReply(input:{pullRequestReviewId:$rev,pullRequestReviewThreadId:$t,body:$b}){comment{id}}}`.
3. Submit: `mutation($rev:ID!){submitPullRequestReview(input:{pullRequestReviewId:$rev,event:COMMENT}){pullRequestReview{url}}}`.
4. For each thread to resolve: `mutation($t:ID!){resolveReviewThread(input:{threadId:$t}){thread{isResolved}}}`.

Until step 3 succeeds the pending review is visible only to the user; when an earlier step fails, it can be removed with `mutation($rev:ID!){deletePullRequestReview(input:{pullRequestReviewId:$rev}){clientMutationId}}`.
