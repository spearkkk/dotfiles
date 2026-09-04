# Personal defaults for the shared ai-review fish function.
# Work-specific configs may override this later in conf.d load order.
if not set -q AI_REVIEW_REVIEWERS
    set -gx AI_REVIEW_REVIEWERS codex claude
end
