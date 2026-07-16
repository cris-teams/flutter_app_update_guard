export type RiskLevel = 'safe' | 'low' | 'medium' | 'high' | 'critical';

export interface RiskReason {
  code: string;
  message: string;
  score: number;
}

export interface DependencyReport {
  name: string;
  currentVersion: string;
  latestVersion?: string;
  updateType: string;
  risk: {
    score: number;
    level: RiskLevel;
    reasons: RiskReason[];
  };
  kind: string;
  section: string;
  constraint?: string;
  sdkCompatibility: string;
  isSkipped: boolean;
  skipReason?: string;
}

export interface CheckReport {
  project: string;
  generatedAt: string;
  summary: Record<string, number>;
  dependencies: DependencyReport[];
  policyViolations: string[];
  warnings: string[];
}

export interface PubspecDependencyLine {
  name: string;
  section: string;
  line: number;
  startCharacter: number;
  endCharacter: number;
}

