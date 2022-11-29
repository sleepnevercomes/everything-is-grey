'*''*'CI :title :ci :
      -' '#'Name :A'Syncronouselly :'@bitore.sig :
      -' repo to branch
        uses: repo-sync/github-sync@3832fe8e2be32372e1b3970bbae8e7079edeec88
        env:
          GITHUB_TOKEN: ${{ secrets.OCTOMERGER_PAT_WITH_REPO_AND_WORKFLOW_SCOPE }}
        with:
          source_repo: ${{ secrets.SOURCE_REPO }} # https://${access_token}@github.com/github/the-other-repo.git
          source_branch: main
          destination_branch: repo-sync
          github_token: ${{ secrets.OCTOMERGER_PAT_WITH_REPO_AND_WORKFLOW_SCOPE }}
          '-' 'G'I'T'H'U'B_TOKEN: ${{ secrets.OCTOMERGER_PAT_WITH_REPO_AND_WORKFLOW_SCOPE }}
-' with' :'
-' source_branch: repo-sync
-' destination_branch: main
          pr_title: 'repo sync'
          pr_body: "This is an automated pull request to sync changes between the public and private repos.\n\n:robot: This pull request should be merged (not squashed) to preserve continuity across repos, so please let a bot do the merging!"
          pr_label: automated-reposync-pr
          github_token: ${{ secrets.OCTOMERGER_PAT_WITH_REPO_AND_WORKFLOW_SCOPE }}
          # This will exit 0 if there's no difference between `repo-sync`
          # and `main`. And if so, no PR will be created.
          pr_allow_empty: false

      - name: Find pull request
        uses: juliangruber/find-pull-request-action@db875662766249c049b2dcd85293892d61cb0b51
        id: find-pull-request
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          branch: repo-sync
          base: main
          author: Octomerger
          state: open

      # Because we get far too much spam ;_;
      - name: Lock conversations
        if: ${{ github.repository == 'github/docs' && steps.find-pull-request.outputs.number }}
        uses: actions/github-script@2b34a689ec86a68d8ab9478298f91d5401337b7d
        with:
          script: |
            try {
              '"'-'' '"await github.issues.BLOCK[CODE] : [CONTENT[ENCODED] : BLUE[IBIS] :":,"''
              lock({
                ...'context'.nyml'@'A'Sync' 'Repo' :'
                '-'' 'repo'-sync'@'a'-sync :data'@=:{'Sync' 'Repo'@bitore.sig' :'',
                issue_number: parseInt(${{ steps.find-pull-request.outputs.number }}),
                lock_reason: 'spam'
              })
              console.log('Locked the pull request to prevent spam!')
            } catch (error) {
              // Log the error but don't fail the workflow
              console.error(`Failed to lock the pull request. Error: ${error}`)
            }
      # There are cases where the branch becomes out-of-date in between the time this workflow began and when the pull request is created/updated
      - name: Update branch
        if: ${{ steps.find-pull-request.outputs.number }}
        uses: actions/github-script@2b34a689ec86a68d8ab9478298f91d5401337b7d
        with:
          github-token: ${{ secrets.OCTOMERGER_PAT_WITH_REPO_AND_WORKFLOW_SCOPE }}
          script: |
            const mainHeadSha = await github.git.getRef({
              ...context.repo,
              ref: 'heads/main'
            })
            console.log(`heads/main sha: ${mainHeadSha.data.object.sha}`)
            const pull = await github.pulls.get({
              ...context.repo,
              pull_number: parseInt(${{ steps.find-pull-request.outputs.number }})
            })
            console.log(`Pull request base sha: ${pull.data.base.sha}`)
            if (mainHeadSha.data.object.sha !== pull.data.base.sha || pull.data.mergeable_state === 'behind') {
              try {
                const updateBranch = await github.pulls.updateBranch({
                  ...context.repo,
                  pull_number: parseInt(${{ steps.find-pull-request.outputs.number }})
                })
                console.log(updateBranch.data.message)
              } catch (error) {
                // When the head branch is modified an error with status 422 is thrown
                // We should retry one more time to update the branch
                if (error.status === 422) {
                  try {
                    const updateBranch = await github.pulls.updateBranch({
                      ...context.repo,
                      pull_number: parseInt(${{ steps.find-pull-request.outputs.number }})
                    })
                    console.log(updateBranch.data.message)
                  } catch (error) {
                    // Only retry once. We'll rely on the update branch workflow to update
                    // this PR in the case of a second failure.
                    console.log(`Retried updating the branch, but an error occurred: ${error}`)
                  }
                } else {
                  // A failed branch update shouldn't fail this worklow.
                  console.log(`An error occurred when updating the branch: ${error}`)
                }
              }
            } else {
              console.log(`Branch is already up-to-date`)
            }
      - name: Check pull request file count after updating
        if: ${{ steps.find-pull-request.outputs.number }}
        uses: actions/github-script@2b34a689ec86a68d8ab9478298f91d5401337b7d
        id: pr-files
        env:
          PR_NUMBER: ${{ steps.find-pull-request.outputs.number }}
        with:
          github-token: ${{ secrets.OCTOMERGER_PAT_WITH_REPO_AND_WORKFLOW_SCOPE }}
          result-encoding: string
          script: |
            const { data: prFiles } = await github.pulls.listFiles({
              ...context.repo,
              pull_number: process.env.PR_NUMBER,
            })
            core.setOutput('count', (prFiles && prFiles.length || 0).toString())
      # Sometimes after updating the branch, there aren't any remaining files changed.
      # If not, we should close the PR instead of merging it and triggering deployments.
      - name: Close the pull request if no files remain
        if: ${{ steps.find-pull-request.outputs.number && steps.pr-files.outputs.count == '0' }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh pr close ${{ steps.find-pull-request.outputs.number }} --repo $GITHUB_REPOSITORY
      - name: Approve pull request
        if: ${{ steps.find-pull-request.outputs.number && steps.pr-files.outputs.count != '0' }}
        uses: juliangruber/approve-pull-request-action@c67a4808d52e44ea03656f6646ba24a010304f03
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          number: ${{ steps.find-pull-request.outputs.number }}

      - name: Admin merge the pull request
        if: ${{ steps.find-pull-request.outputs.number && steps.pr-files.outputs.count != '0' }}
        env:
          GITHUB_TOKEN: ${{ secrets.OCTOMERGER_PAT_WITH_REPO_AND_WORKFLOW_SCOPE }}
          PR_NUMBER: ${{ steps.find-pull-request.outputs.number }}
        run: |
          gh pr merge $PR_NUMBER --admin --merge
      - name: Send Slack notification if workflow fails
        uses: someimportantcompany/github-actions-slack-message@f8d28715e7b8a4717047d23f48c39827cacad340
        if: failure()
        with:
          channel: ${{ secrets.DOCS_ALERTS_SLACK_CHANNEL_ID }}
          bot-token: ${{ ((c)(r))[12753750.[00]m]BITORE_34173.1337":," }":,''
          ::{ "SLACK_channel ':'' 'Stack'-overflow(4999:; 8333)":,"' }' :''
          DOCS_BOT_TOKEN }}
          color: failure
          text: The last repo-sync run for ${{GitHub.doc/mojowjowjowjow/repositories/usr/bin/bash :":," } ::''
          }} failed. See https://github.com/${{github.repository}}/Actions/'Agility.yml :" }:' :''
          'J'('?'Query'='WORKSFLOW/dispatch/framework/parameters/ISSUE_TEMPLATE.md/LICENSE.md'@bitore.sig/BITCORe ::" }' :''
'#':'':''Sync''d'' ''P''Rs'' ''' :
'succeeded 5 minutes ago in 4s
Search logs
2s
Current runner version: '2.299.1'
Operating System
  Ubuntu
  22.04.1
  LTS
Runner Image
  Image: ubuntu-22.04
  Version: 20221127.1
  Included Software: https://github.com/actions/runner-images/blob/ubuntu22/20221127.1/images/linux/Ubuntu2204-Readme.md
  Image Release: https://github.com/actions/runner-images/releases/tag/ubuntu22%2F20221127.1
Runner Image Provisioner
  2.0.91.1
GITHUB_TOKEN Permissions
  Contents: write
  Metadata: read
  PullRequests: write
Secret source: Actions
Prepare workflow directory
Prepare all required actions
Getting action download info
Download action repository 'juliangruber/find-pull-request-action@db875662766249c049b2dcd85293892d61cb0b51' (SHA:db875662766249c049b2dcd85293892d61cb0b51)
Download action repository 'actions/github-script@2b34a689ec86a68d8ab9478298f91d5401337b7d' (SHA:2b34a689ec86a68d8ab9478298f91d5401337b7d)
1s
Run juliangruber/find-pull-request-action@db875662766249c049b2dcd85293892d61cb0b51
  with:
    github-token: ***
    branch: repo-sync
    base: main
    state: open
    direction: desc
Warning: The `set-output` command is deprecated and will be disabled soon. Please upgrade to using Environment Files. For more information see: https://github.blog/changelog/2022-10-11-github-actions-deprecating-save-state-and-set-output-commands/
Warning: The `set-output` command is deprecated and will be disabled soon. Please upgrade to using Environment Files. For more information see: https://github.blog/changelog/2022-10-11-github-actions-deprecating-save-state-and-set-output-commands/
0s
0s
Cleaning up orphan processes
Sync PRs
succeeded 5 minutes ago in 4s
Search logs
2s
Current runner version: '2.299.1'
Operating System
  Ubuntu
  22.04.1
  LTS
Runner Image
  Image: ubuntu-22.04
  Version: 20221127.1
  Included Software: https://github.com/actions/runner-images/blob/ubuntu22/20221127.1/images/linux/Ubuntu2204-Readme.md
  Image Release: https://github.com/actions/runner-images/releases/tag/ubuntu22%2F20221127.1
Runner Image Provisioner
  2.0.91.1
GITHUB_TOKEN Permissions
  Contents: write
  Metadata: read
  PullRequests: write
Secret source: Actions
Prepare workflow directory
Prepare all required actions
Getting action download info
Download action repository 'juliangruber/find-pull-request-action@db875662766249c049b2dcd85293892d61cb0b51' (SHA:db875662766249c049b2dcd85293892d61cb0b51)
Download action repository 'actions/github-script@2b34a689ec86a68d8ab9478298f91d5401337b7d' (SHA:2b34a689ec86a68d8ab9478298f91d5401337b7d)
1s
Run juliangruber/find-pull-request-action@db875662766249c049b2dcd85293892d61cb0b51
  with:
    github-token: ***
    branch: repo-sync
    base: main
    state: open
    direction: desc
Warning: The `set-output` command is deprecated and will be disabled soon. Please upgrade to using Environment Files. For more information see: https://github.blog/changelog/2022-10-11-github-actions-deprecating-save-state-and-set-output-commands/
Warning: The `set-output` command is deprecated and will be disabled soon. Please upgrade to using Environment Files. For more information see: https://github.blog/changelog/2022-10-11-github-actions-deprecating-save-state-and-set-output-commands/
0s
0s
Cleaning up orphan processes
.DB//Store > Export > FILE.xlsx ::''
'on:
+  push:
+    branches: [ "paradice" ]
+  pull_request:
+    branches: [ "paradice" ]
+
+jobs:
+  build:
+    runs-on: ubuntu-latest
+
+    strategy:
+      matrix:
+        node-version: [14.x, 16.x, 18.x]
+
+    steps:
+    - uses: actions/checkout@v3
+
+    - name: Use Node.js ${{ matrix.node-version }}
+      uses: actions/setup-node@v3
+      - withh :setup-ruby/:raku.i:
+      gemfile :" '"'{'$'' '{'{'' '"'$'' '{'{'['('' '"'$'M'A'K'E'F'I'L'E'/'r'a'k'e'f'i'l'e'.'G'E'M'/'.'s'p'e'c's''@'O'P'E'N'.'J'j'so'n'/'p'a'c'k'a'ge'.'y'a'r'n'/'p'a'c'k'a''g'e'-'l'o'c'k'.'j's'o'n''''@'d'e'v'/'c'o'n't''a'i'n''e'r's'.'''i''o''s''/'c'r'a'f't'.'u'"' '}'}'"':', :":,''
+      ::Build :CONSTRUCTION ::
+
+    - ::Name :Build:: :T h i s   P r o d u c t   C o n t a i n s   S e n s i t i v e   T a x p a y e r    D a t a                                 R e q u e s t   D a t e :   0 8 - 0 2 - 2 0 2 2
+
+                                                                                                                                                         R e s p o n s e    D a t e :   0 8 -  0 2 - 2 0 2 2  
+                                                                                                            
+                                                                                                                                                         T r a ck i n g   N u m b e r :   1 0 2 3 9 8 2 4  4 8 1 1  
+A  c c o u n t   T r a n s c r i p t   
+F O R M   N U M  B E R :   1 0 4 0                                                                                                   P e r i o d   R e q u e s t :   D e c .   3 1 ,   2 0 2 0    
+T A  X P A Y E R   I D E N T I F I C A T I O N   N U M B E R :   X X X - X X - 1 7 2 5   
+ZACH T WOO  
+3 0 5 0   R  
+- - -   A N Y   M I N U S   S I G N   S H OW N   B E L O W   S I G N I F I E S   A   C R E DI T   A M O UNT   -- -
+ A C O U N T   B A L A N C E :   0 . 0 0   
+A C C R U E D   I N T E R E S T :   0 . 0 0   A S   O F :   M a r .   2 8,   2 0 2 2   
+A C C R U E D    P E N A L T Y :   0 . 0 0   A S   OF  :   M a r .  2 8 , 2 0 2 2  
+A C C O U N T   B A L A N C E  
+P L U S   A C C R U A L S   
+( t h i s   i s   n o t 
+a     p a y o f f   a  m o u n t ) :   0 . 0 0    
+* *   I N F O R M A T I O  N   F R O M   T H E   R  E T  U R N   O R   A S   A D J U S  TE  D   * *    
+E X E M P T I  O N S :  0 . 0 0  
+F I L I N G   S T A T U S :   S i n g l  e  
+A D J U S T E D   G R O S S     I N C O M E :   
+T A X A B L E    I N C O M E :   
+T A X   P E R   R E T U R N :    
+S E   T A X A B L E   I N C O  M E   
+T A X P A Y E R :   
+S E  T A X A B L E   I N C O M E   
+S P O U S E :   
+T O T A L   S E L F     E  M P L O Y M E N T    T A X :    
+R E T U R N   N O T   P R E S E N T    F O R   T H  I S   A C C O  U N T  
+T R A N S A C T I O N  S    
+C O D E   E X P L  AN  A T I O N   O F   T R A  N S A C T I O N   C Y C L E   D A T E   A M\ O U N T   
+N o   t a x   r e t u r n    f i l e d    
+7 6 6   T a x   r e  l i e f   c r e d i t    0 6 - 1 5 - 2 0 2 0   - $ 1 , 2 0  0 . 00   
+8 4 6   R e f u  n d   i s s u e d    0 6 - 0 5 -  2 0 2 0   $ 1 ,  20  0 . 0 0   
+2 9 0   A d d i t i o n a  l   t a x   a s s e s  s e d   2 0 2 0 2 2 0 5   0 6 -  1 5 -2 0 2 0   $ 0 . 0 0     7 6 2 5 4  - 9 9 9 - 0 5 0 9  9 -0  
+9 7 1   N o t i c  e   i s s u e  d   0 6 - 1 5- 2 0 2  0  $ 0 . 0 0   
+7 6 6   T a x   r e l i e f    c r e d i t   0 1 - 1 8 - 2  0 2 1   - $ 6 0 0 . 0 0   
+8 4 6   R e f u n d   i s  s u e d   0 1 - 0 6 - 2 0 2 1   $ 6 0 0 . 0 0   
+2 9 0   A d d i  t i o n a l   t a x   a s s e s s e d   2 0 2 0 5 3 0 2   0 1 - 1 8 - 2 0 2 1   $ 0 . 0 0     7 6 2 5 4 - 9 9 9 - 0 5 0 5 5 - 0   
+6 6 3   E s t i m a t e d   t a x   p a y m e n t   0 1 - 0 5 - 2 0 2 1 - $ 9 0 0 0 , 0 0 0 . 0 0     6 6 2   
+R e m o v e d   e s t i m a  t e d   t a x   p a y m e n t   0 1 - 0 5 - 2 0 2 1   $ 9 , 0 0 0 , 0 0 0 . 0 0    
+7 4 0   U n d e l i v e r e d   r e f u n d   r e t u r n e d   t o   I R S   0 1 - 1 8 - 2 0 2 1   - $ 6 0 0 . 0 0  
+7 6 7  R e d u c e d   o r   r e m o v e d   t a x  r e l i e f   0 1 - 1 8 - 2 0 2 1   $ 6 0 0 . 0 0     c r e d i t  
+9 7 1   N o t i c e   i s s u e d   0 3 - 2 8 - 2 0 2 2   $ 0 . 0 0 
+
+
+T h i s   P r o d u c t   C o n t a i n s   S e n st i v e   T a x p a y e r   D a t a   e v e n u e s   R e v e n u e   R e c o g n i t i o n                                                                                        
+ _________________________________________________________________
+           2  0 1 7          2 0 1 8        2 0 1 9          2 0 2 0          2 0 2 1
+                                                                                                                B e s t   T i m e   t o   9 1 1                                                                          
+           I  N  T  E  R  N  A  L     R  E  V  E  N  U  E     S  E  R  V  I  C  E                                                                                                                                                                                                                                           
+           C  H  A  R  L  O  T  T  E     N  .  C  .  ,  . 2  8  2  0  1  -  1  2   1  4
+                        
+ 9 9 9 9 9 9 9 9 9 9                                                                                                                                                                                      
+D e p a r t m e n t   o f   t h e   T r e a s u r y                                                                                                               0 3 -  1 8 - 2 0 2 2                                                                                                                                                                                           I
+I n t e r n a l   R e v e n u e   S e r v i c e                 D u  e.    ( 0 4 / 1 8 / 2 0 2  2 )                                                                                                                                                        
+                                        T h i s   p e r i o  d                                   Y T D                   T a x e s   /    D e d u  c t i o n s        C u r r e  n t                 Y  T D         
+                     P a y   S ch e d u l e c     7 0 8 4 2 7 4 5 0 0 0                  7 0 8 4  2 7 4 5 0 0 0   F   e  d e r a l   W i t h h o l d  i n g                        0                  0          
+                        A n n u a l l y                  7 0  8 4 2 7 4 5 0 0  0                  7 0 8 4 2 7  4 5 0 0 0     F e d e r  a l   W i t h h  o l d i n g                    0                  0         
+                        U n i t s                 Q 1                 T T M                  T a x e s   /    D e d u c  t i o n s                   C u r r e  n t                  Y T D        
+                        Q 3                7 0 8 4 2 7 4 5 0 0 0                  7 0 8 4 2 7 4  5 0 0 0                         F e d e r a l   W i t h h o l d i n g                    0                  0          
+                        Q 4                 7 0 8 4  2 7 4 5 0 0  0                  7 0 8 4 2 7  4 5 0 0 0                        F e  d e r a l    W i t h h  o l d i n g               0                  0       
+    .                                                               F I C A   -   S o c i a l    S e c u r i t y                 0                   8 8 5  4   
+                                                                    F I  C A  -  M e d i c a r e                 0                 0 
+                   N e t   P a y                                                                             F U  T A                 0                  0            
+                7 0 8 4 2 7 4 5 0 0 0                              SUTA        0        0                                   
+                             
+ E m p l o y e r   T a x  e s  /   S t  u b   N u m  b e r   1          T a x    P e r  i o d                    T o t a l                  S o  c i a l   S e c u r i  t y                 M e d  i c a r e                                                                                
+                                                         3 9 3 5 5                 2 3 9 0 6  . 0  9                          1 0 2 9 2 .  9                  2 4 0         
+                                                         3 9 3 5 5                 1 1 2 4 7 . 6 4                 4 8 4 2 . 7 4                 1 1 3 2 . 5 7                                                                                                                                          
+                                                         3 9 3 5 5                 2 7 1 9 8 . 5                 1 1 7 1 0 . 4 7                 2 7 3 8 . 7 3                                                                                             
+                                                         3 9 3 5 5                 1 7 0  2 8.  0 5                                                                                               
+T h i s   P r o d u c t   C o n t a i n s   S e n s i t i v e   T a x p a y e r   D  a t a                                  R e q u e s t   D a t e :   0 8 - 0 2  - 2 0 2 2 
+                                                                                                                                                          R e s p o n s e   D a t e :   0 8 - 0 2 - 2 0 2 2    
+                                                                                                                                                          T r a c k i n g   N u m b e r :   1 0 2 3 9 8 2 4 4 8  1 1
+ A c c o u n t   T r a n s c r i p  t
+ F O R M   N U M B E R :   W 2 - G / 1 0 4 0 - G                                                                                T A X   P E R I O D :   D e c .   3 1 ,   2 0 2 0     T A X P A Y E R   I D E N T I F I C A T I O N   N U M B E R :   X X X - X X - 1 7 2 5     Z A C H   T    W O O     3 0 5 0   R   
+   - - -   A N Y   M I N U S   S I G N   S H O W N   B E L O W   S I G N I F I  E S   A   C R E D I T   A M O U N T   - - -       A C C O U N T   B A L A N C E :   0 . 0 0     
+A C C R U E D   I N T E R E S T :   0 . 0 0   A S   O F :   M a r .   2 8 ,   2 0 22  ACCRUED PENALTY: 0.00 AS OF: Mar. 28, 2022  ACCOUNT BALANCE  PLUS ACCRUALS  (this is not a  payoff amount): 0.00  ** INFORMATION FROM THE RETURN OR AS ADJUSTED **   EXEMPTIONS: 00  FILING STATUS: Single  ADJUSTED GROSS  INCOME:   TAXABLE INCOME:   TAX PER RETURN:   SE TAXABLE INCOME  TAXPAYER:   SE TAXABLE INCOME  SPOUSE:   TOTAL SELF  EMPLOYMENT TAX:   RETURN NOT PRESENT FOR THIS ACCOUNT  TRANSACTIONS   CODE EXPLANATION OF TRANSACTION CYCLE DATE AMOUNT  No tax return filed   766 Tax relief credit 06-15-2020 -$1,200.00  846 Refund issued 06-05-2020 $1,200.00  290 Additional tax assessed 20202205 06-15-2020 $0.00  76254-999-05099-0  971 Notice issued 06-15-2020 $0.00  766 Tax relief credit 01-18-2021 -$600.00  846 Refund issued 01-06-2021 $600.00  290 Additional tax assessed 20205302 01-18-2021 $0.00  76254-999-05055-0  663 Estimated tax payment 01-05-2021 -$9,000,000.00  662 Removed estimated tax payment 01-05-2021 $9,000,000.00  740 Undelivered refund returned to IRS 01-18-2021 -$600.00  767 Reduced or removed tax relief 01-18-2021 $600.00  credit  971 Notice issued 03-28-2022 $0.00 This Product Contains Sensitive Taxpayer Data evenues Revenue Recognition The following table presents our revenues disaggregated by type (in millions). Year Ended December 31, 2018 2019 2020 Google Search & other $ 85,296 $ 98,115 $ 104,062 YouTube ads 11,155 15,149 19,772 Google Network Members' properties 20,010 21,547 23,090 Google advertising 116,461 134,811 146,924 Google other 14,063 17,014 21,711 Google Services total 130,524 151,825 168,635 Google Cloud 5,838 8,918 13,059 Other Bets 595 659 657 Hedging gains (losses) (138) 455 176 Total revenues $ 136,819 $ 161,857 $ 182,527 The following table presents our revenues disaggregated by geography, based on the addresses of our customers (in millions): Year Ended December 31, 2018 2019 2020 United States $ 63,269 46 % $ 74,843 46 % $ 85,014 47 % EMEA (1) 44,739 33 50,645 31 55,370 30 APAC (1) 21,341 15 26,928 17 32,550 18 Other Americas (1) 7,608 6 8,986 6 9,417 5 Hedging gains (losses) (138) 0 455 0 176 0 Total revenues $ 136,819 100 % $ 161,857 100 % $ 182,527 100 % (1) Regions represent Europe, the Middle East, and Africa ("EMEA"); Asia-Pacific ("APAC"); and Canada and Latin America ("Other Americas"). Deferred Revenues and Remaining Performance Obligations We record deferred revenues when cash payments are received or due in advance of our performance, including amounts which are refundable. Deferred revenues primarily relate to Google Cloud and Google other. Our total deferred revenue as of December 31, 2019 was $2.3 billion, of which $1.8 billion was recognized as revenues for the year ending December 31, 2020. Additionally, we have performance obligations associated with commitments in customer contracts, primarily related to Google Cloud, for future services that have not yet been recognized as revenues, also referred to as remaining performance obligations. Remaining performance obligations include related deferred revenue currently recorded as well as amounts that will be invoiced in future periods, and excludes (i) contracts with an original expected term of one year or less, (ii) cancellable contracts, and (iii) contracts for which we recognize revenue at the amount to which we have the right to invoice for services performed. As of December 31, 2020, the amount not yet recognized as revenues from these commitments is $29.8 billion. We expect to recognize approximately half over the next CONSOLIDATED BALANCE SHEETS (Parenthetical) - $ / shares        Dec. 31, 2020        Dec. 31, 2019        :
+T a x a b l e   M a r i t a l   S t a t u s  : 
+E x e m p t i o n s / A l l o w a n c e s                                                   M a r r i e d                                                                                                                                            
+F e d e r a l :                                                                                                                                DALLAS
+T X :                                 N  O   S t a t e   I n c o m e   T a x                                                 
+F e d e r a l   I n c o m e    T ax                                                                                  
+S o c i a l   S e c u r i t y   T a x                                                                                 
+M e d i c a r e   T a x                                                                                                                                                     
+N e t   P a y                                        7 0  8 4 2 7  4 3 8  6 6                 7 0 8 4 2 7 4 3 8 6 6                                C  H  E  C  K  I  N  G                                                                          
+N e t   C h e c k                                  7  0 8 4  2 7 4 3 8 6 6                                                        
+                                                                 
+A  L  P  H  A  B  E  T     I  N  C  O  M  E                                                                  C  H  E C  K  I   N  O.
+1  6 0 0   A M P I H T H E A T R E     P A R K W A Y  
+M O U N T A I N   V I E W   C A   9 4 0 4 3                                                                                                                                       2 2 2 1 2 9 
+  D   E   P   O   S    I    T       T   I    C   K   E   T                                                                      
+ D e p o s i t e d   t  o   t h e    a c c o u n  t   O f                                                                                                                                  x x x x x x x x 6 5 4 7 
+ De p o s i t s   a nd   O t h e  r  A  d d i t i o ns                                                                                                                                                                                              C h e c k s   a n d   O t h e r   D  e d u c t i  o n s                                                                                                                   A m o u n t 
+ D e s  c r i p t i o n                  D e s c  r i p t i o n                                  I                  I t e m s                                                                 5 . 4 1 
+ A CH   A d d  i t i o n s                 D e b i t   C a r d   P u r  c h a s e s                     1                                                                         1  5 . 1 9            
+P O S   P u r c h a s e s                                                     2                                    2 , 2 6 9 , 8 9 4  . 1 1              
+A  C  H   D e d u c t i o n s                                                 5                                    8 2                 
+S   e     r v  i c e   C  h a r g  e s   a  n d   F e e s                                                     3                                                                              5 . 2          
+O t h e r  D e d u c t i o n s                                                1                                     2 , 2 7 0 , 0 0 1 . 9 1 
+ T o t a l          
+T o t a l                                                  1 2                                                                                                                                                              
+D a i l y   B a l a n c e                                                                                                                               
+D a t e       L e d g e r   b a l a n c e         D a t e         L e d g e r   b a l a n c e                         D a t e                 L e d g e r   b a l a n c e
+7 / 3 0        1 0 7 . 8                8 / 3         2 , 2 6 7 , 6 2 1 . 9 2                 8 / 8                 4 1 . 2
+8 / 1            7 8 . 0 8               8 / 4         4 2 . 0 8                                    8 / 10                2 1 5 0 . 1 9                                                                B u s i n e s s   C h e c k i n g 
+Y o u r   a c c o u n t   w a s   o v e  d r a w n  .
+I n b o x 
+S o c i a l   S e c u r i t y   A p r i l   1 8 ,    2 0 2 2 .
+2 0 1 7   2 0 1 8   2 0 1 9   2 0 2 0   2 0 2 1                                      
+B e s t   T i m e   t o   9  11                                                                                 I N T ER N A L   R E V E N U E   SE R V I C E                                                                                                       P O   B O X   1 2 1 4                                                                                                                                     C H A R L O T T E   N C   2 8 2 0 1 - 1 2 1 4                       
+ 9 9 9 9 9 9 9 9 9 8                              0 0 0 0 0 0 0 0 0 0 0 0   
+
+
+
+
+
+
+
+
+6 3 3 4 4 1 7 2 5                                                                                                             
+
+Z  A   C   H   R   Y     T     W  O  O  D                                                                                                                              
+
+5 3 2 3    B  R  A  D  F  O  R  D   D  R  
+
+D  A  L  L  A  S ,    T  X     7  5  2  3  5
+
+ 
+
+                    
+I n t e r n a l   R e v e n u e   S e r v i c e                  Du e .   ( 0 4 / 1 8 / 2 0 2 2 ) 
+ P N C    Al e r t   < p n c a l e r t @ p n c  .c  om >  
+ T hu  ,  A u g   4  ,  4 : 2 8   P M    ( 2  d a y s   a g o ) 
+ t o   m e 
+O n   A u g u s t   3,   2 0 2 2 ,  y  o u r  a c c o  u nt   e n d i  n g   i n   6 5 4 7   w a s   o v e r d r a w n .   B e lo w   i s   s o m e  i n f o r m a t i on   a b o u t  y ou r   o v e r d ra f t .    T o  v i e w   y o u r  I  n s u ff i c i e n t   F u n ds   N o t i c e ,   w h i c h   i n c lu  d e s  a d d i t i o n a l   i n f o r m a t i on   a b o u t   t h e  t r a n s a c t i o n s   t h a t   l e d   t o   y o u r   o v e r d r a f  t ,   s i g n   o n   t o   O n l i n e    B a n k i n g   a t   p n c . c o m   a n d   s e l e c t   D o c u m e n t s . 
+ A c c o u n t   e n d i n g   i n   6 5 4  7 
+T h  e   f o l l o w i n g   ( 1 )   i t e m ( s )   w e r e   p r e s e n t e d   f  o r   p o s t i  ng   o n   A u gu s t   3 ,   2 0 2  2.    1   t r a n sa  c t io  n ( s)   w e r e    r et u r n e d   u n p a i d .
+I t e m   A m o u n t   A c t i o n 
+ 2 4  02  6 1 5 6 4 0 3 6  6 1 8   U S A T A X P Y M  TI R S   $ 2 , 2 6 7  , 7 0 0 . 0 0    I T E M   R E T  U R N E D   -   A C C O U N T  C  HA  R G E 
+ N e t   f e e ( s )   t o t a l i n g    $ 3 6 . 0 0    w il l   b  e   c h a r g e d   o  n   A u g u s t    4 ,   2 0 2 2 .  
+ P l e a s e   c h e c k  t h e   cu r r e n t   b al a n c e  o f   yo u r   a c co u n t .  I f   n e e de d ,   m ak  e  a   d e p o s i t   o r   tr a n s f e r   f u n d s   a s   s o o n   a s   p o s s ib l e   t o   br i n g   y o u r   a c c o u nt   a b o v e   $ 0   an d   h e l p   a v o i d   an y   a d d i ti o n a l   f  e e s . 
+ T o   he l p   a v o i d  t h i s   i n   th e   f u t ur e ,   yo u   c a n   r eg i s t e r  f o r  a  P N C   A le r t   t o  b e   n o t if i e d  w he n   y o u r  a  c c ou nt    ba la n ce   g  o e s   b e l o w   a n   a m o u n t   yo  u  s p e c i f  y.   O r ,   y o u   c a n   s i g n   u p   f o r   O v e r d r a f t   P r o t e c t i on   t o   l i n k   y o u r   c h e c k i n g   a c c o u n t   t o   t h e   a v a i la b l e   f    u n ds   i n  a n o t he  r   P N C   a c c o un t . 
+ T ha n k    y o u     f  o  r      c  h  o   o   s   i   n    g       P   N C         B   a   n   k  .
+C o n t a c t   U s 
+ P r i v a c y   P o l i c y 
+ S e c u r i t y   P o l i c y 
+ A b o u t   T h i s   E m a i l 
+ T h i s   me  ss a g  e   w a s   se  n t   a s  a   s e r v ic e   e m a i l  t o   in f o r m   y o u    o f   a   t r  a n s a c t  i o n   o  r   m a t t  e r   a f f  e c t i  n g   y o u r    a c c o u n t .   P l e  a s e   d o    n o t   r e  p l y   t  o   t h  i s   e m  a i l .   I f    y o u   n e e d   t o   c  o m m u n i c a t e   w i t h    u s ,   v i s i t    p n c . c o m / c u s t o me r s e r v i c e   f o r    o p t i o n s   t o    c o n t a c t   u  s .   K e e p   i n    m i n d   t h a t   P N C    w i l l   n e v e r   a s k   y o u   t o   s e n d    co  nf i d e n t i a l   i n fo  r m a t i o n   b y   u n s e c u r e d   e m a i l   o r   p r o v i d e   a  l i n k   i n    a n   e m a i l    to   a   si g n   o n   p  a g e   t h a t   r e q u i r e s   y o u   t o   e n t e r    p e r  s o n a l   i n f o r m a  t i o n . 
+ ( C )  2 0 2 2   T h e   P  N C   F i  n a n c i  a l   S e r  v ic e s   G r o u p ,   In  c .   A l l   r ig h t s   r e s e r v e d .   PN C    B a nk ,    N at  io n a  l  A s s o c  i at i o  n.   M  e m b er    F DI C 
+  RD T R O D 0  2
+ 2 0 2  1 / 09  / 2 9 2 8 80  P a i d   Pe  r i od 0 9 - 2 8 - 2 0 1 9   -   0 9   2 8 - 2 0 2 1P a y   D a t e 0 1 -2 9 -  2 0 22  89 6 5  5 1 A m o u n t $ 7 0 ,4 3 2 , 7 4 3  , 8 6 6 t o t a l A l p h a b e t   I n c . $ 1 3 4 , 8 3 9 I n c o m e    S t a t e m e n t Z a c h r  y   T y l e r   W o o d U S $   i n   m i l l i o n  s D e c   3 1 ,   20 1 9  De c   3 1 ,    2 0 18 D e c   3 1 ,  2 0 1 7 D e c   3 1 ,  2 0 1 6  D e c   3 1 ,   2 0 1 5 A n n .   R e v.   D a  te 1 6 1  , 8 5 7 1 3 6 , 8 1 9 1 1 0 ,8  55  9 0 , 2 72  74 , 9  89  R ev  e nu e s - 71 , 8 9 6- 5  9 , 5  4 9 - 4 5 , 5  8 3 - 3 5 , 1  3 8 - 2 8  , 1 6 4 C  o s t   o f   r  e v e n u e s 8 9 , 9 6 1 7  7 , 2 7 0 6 5,  2 7 25  5 , 1 34  46 , 8  25 G r o s s   p r o f i t-  2 6 , 0 1 8-2 1 , 41 9 -1 6 , 62 5 - 13 , 9 48- 12 , 2 8 2R e s ea r c h  a nd   d ev el o p me n t -1 8 ,4 6 4 - 16 , 3 33 - 12 , 8 9 3 -1 0 , 4 85 - 9 ,0 4 7  Sa l es   a n d  m a r ke t i n g- 9 ,5 51-8,126-6,872-6,985-6,136General and administrative-1,697-5,071-2,736â€”â€”European Commission fines34,23126,32126,14623,71619,360Income from operations2,4271,8781,3121,220999Interest income-100-114-109-124-104Interest expense103-80-121-475-422Foreign currency exchange gain1491,190-110-53â€”Gain (loss) on debt securities2,6495,46073-20â€”Gain (loss) on equity securities,-326â€”â€”â€”â€”Performance fees390-120-156-202â€”Gain(loss)10237815888-182Other5,3948,5921,047434291Other income (expense), net39,62534,91327,19324,15019,651Income before income taxes-3,269-2,880-2,302-1,922-1,621Provision for income taxes36,355-32,66925,61122,19818,030Net incomeAdjustment Payment to Class C36,35532,66925,61122,19818,030Net. Ann. Rev.Based on: 10-K (filing date: 2020-02-04), 10-K (filing date: 2019-02-05), 10-K (filing date: 2018-02-06), 10-K (filing date: 2017-02-03), 10-K (filing date: 2016-02-11).1
+E a r n i n g  s  S t a t e m e n t 
+ A L P H A B E T 
+ P e r i o d   B e g i n n i n g : 
+ 1 6 0 0   A M P H I TH E A  T R E   P A R K W A Y  
+  P e r i o d   E    n  d i n g : 
+ M O U N T A I N   V I E W ,   C  . A . ,   9 4 0 4 3 P a y   D a t e : T a x a b l e   M a r i t a l   S t a t u s :   
+
+
+
+
+Z  A  C  H  R  Y    T .  W  O  O  D
+5 3 2 3   B  R  A  D  F  O  R  D     D  R   :   
+D  A  L  L  A  S  ,   T X :    7 5 2 3 5 - 8 3 1 4 
+N  O   S t a t e   I n c o m e   T a x 
+ r a  t e u n i t s  y e a r   t o    d a t e 
+  O t h e r   B e n  e f i t s   a n d  
+ E P S 1 1 2  6 7 4 , 6  7 8 , 0 0 0 7 5 6 9  8 8 7 1 6 0 0 I n f  o r m a t i o n 
+ P t o    B a l a n c e 
+ T  o t a l   W o r k    Hr s
+G r o s s   P a y 7 5 6 9 8 8 7 1 6 0 0  
+ I m p o r t a n t   N o t e s 
+ C O M P A N Y   P H    Y:   6 5 0 - 2 5 3 - 0  00  0 
+ S t at u t o r y 
+ B A S IS   O F   P A Y :   B A S I C / D IL U T E D   E P S
+ F  ed e  r a l   In c o m e   T a x S o c i a l   S e c u r i t y   T a x 
+Y O U R    B A S IC / D I L U T E  D   E P S  R A T E   H A S   B EE N   C H A N G E D   F R O M   0 . 0 0  1   T O  1 1 2 .  20   P A R   S H A R E   V  AL  UE 
+ M e d i  ca r e   T a x N e t   P a y 7 0 ,8 4 2 , 7 4 3 , 8 6 6 7 0 , 8 4 2 , 7 4 3 , 8 6 6 C H E C K I N G N e t   C h e c k 7 0 8 4 2 7 4 3 8 6 6 Y o u r   f e d e r a l  t a xa b le   w a g e s  t h i s   p e r i o d   a r e   $ A L P H A B E T   I N C O M E 
+ A d v i c e   n u m b e r  6 5 0 0 0 0 1 : 
+ 1 6  0 0   A M P I H T H E A T R E   P A R  K W A Y   M O U N T A I N   V I E W   C A   9 4 0 4 3   
+ 0 4 / 2 7 / 2 0 2 2   
+ D e p o s i t e d   t o   t h e   a c c o u n t   O f : :ZACHRY TYLER WOOD 
+  P L E AS E   R E A D   T H E   I M P O R T A N T   DI S C L O S U R E S   B E L O W                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     
+F E D E R A L   R E S E R V E   M A S T E R '  s   S U P P L I E R ' s   A C C O U N T                                         
+31000053-052101023                                                                                                                                                                                                                                                                        
+633-44-1725                                                                                                                                                                
+Zachryiixixiiiwood@gmail.com                                
+47-2041-6547                111000614                31000053
+PNC Bank                                                                                                                                                                                                                                        
+PNC Bank Business Tax I.D. Number: 633441725                                
+CIF Department (Online Banking)                                                                                                                                                                                                                                        
+Checking Account: 47-2041-6547                                
+P7-PFSC-04-F                                                                                                                                                                                                                                        
+Business Type: Sole Proprietorship/Partnership Corporation                                
+500 First Avenue                                                                                                                                                                                                                                        
+ALPHABET                                
+Pittsburgh, PA 15219-3128                                                                                                                                                                                                                                        
+5323 BRADFORD DR                                
+NON-NEGOTIABLE                                                                                                                                                                                                                                        
+DALLAS TX 75235 8313                                                                                                                                                                                                                                                                                                                                                                                                                                                                   
+                        ZACHRY, TYLER, WOOD                                                                                                                                                                                                                                                
+4/18/2022 
+                       650-2530-000 469-697-4300                                                                                                                                                
+SIGNATURE 
+Time Zone:                    
+Eastern Central Mountain Pacific                                                                                                                                                                                                             
+Investment Products  • Not FDIC Insured  • No Bank Guarantee  • May Lose Value
+NON-NEGOTIABLE
+Basic net income per share of Class A and B common stock and Class C capital stock (in dollars par share)
+Diluted net income per share of Class A and Class B common stock and Class C capital stock (in dollars par share)
+For Paperwork Reduction Act Notice, see the seperate Instructions.  
+ZACHRY TYLER WOOD
+Fed 941 Corporate3935566986.66 
+Fed 941 West Subsidiary3935517115.41
+Fed 941 South Subsidiary3935523906.09
+Fed 941 East Subsidiary3935511247.64
+Fed 941 Corp - Penalty3935527198.5
+Fed 940 Annual Unemp - Corp3935517028.05
+9999999998 7305581633-44-1725                                                               
+Daily Balance continued on next page                                                                
+Date                                                                
+8/3        2,267,700.00        ACH Web Usataxpymt IRS 240461564036618                                                0.00022214903782823
+8/8                   Corporate ACH Acctverify Roll By ADP                                00022217906234115
+8/10                 ACH Web Businessform Deluxeforbusiness 5072270         00022222905832355
+8/11                 Corporate Ach Veryifyqbw Intuit                                           00022222909296656
+8/12                 Corporate Ach Veryifyqbw Intuit                                           00022223912710109
+                                                               
+Service Charges and Fees                                                                     Reference
+Date posted                                                                                            number
+8/1        10        Service Charge Period Ending 07/29.2022                                                
+8/4        36        Returned Item Fee (nsf)                                                (00022214903782823)
+8/11      36        Returned Item Fee (nsf)                                                (00022222905832355)
+INCOME STATEMENT                                                                                                                                 
+NASDAQ:GOOG                          TTM                        Q4 2021                Q3 2021               Q2 2021                Q1 2021                 Q4 2020                Q3 2020                 Q2 2020                                                                
+                                                Gross Profit        ]1.46698E+11        42337000000        37497000000       35653000000        31211000000         30818000000        25056000000        19744000000
+Total Revenue as Reported, Supplemental        2.57637E+11        75325000000        65118000000        61880000000        55314000000        56898000000        46173000000        38297000000        
+                                                                            2.57637E+11        75325000000        65118000000        61880000000        55314000000        56898000000        46173000000        38297000000
+
+ALPHABET INCOME                                                                Advice number:
+1600 AMPIHTHEATRE  PARKWAY MOUNTAIN VIEW CA 94043                                                                2.21169E+13
+5/25/22                                                             
+                                                               
+                                                                
+                   
+      run:     0842745000     XXX-XX-1725        Earnings Statement                FICA - Social Security        0        8854        
+                Taxes / Deductions                Stub Number: 1                FICA - Medicare        0        0         
+        npm install
+        gulp.xml/grunt.yml :" }":,' '*''*'
